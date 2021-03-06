!  SVN:$Id: $
!=======================================================================

! Flux variable declarations for biogeochemistry
!
! author Elizabeth C. Hunke, LANL
!
      module ice_flux_bgc

      use ice_kinds_mod
      use ice_blocks, only: nx_block, ny_block
      use icepack_intfc_shared, only: max_aero, max_nbtrcr, &
                max_algae, max_doc, max_don, max_dic, max_fe
      use ice_domain_size, only: max_blocks, ncat

      implicit none
      private

      public :: bgcflux_ice_to_ocn 
      save

      ! in from atmosphere

      real (kind=dbl_kind), &   !coupling variable for both tr_aero and tr_zaero
         dimension (nx_block,ny_block,max_aero,max_blocks), public :: &
         faero_atm   ! aerosol deposition rate (kg/m^2 s)   

      real (kind=dbl_kind), &
         dimension (nx_block,ny_block,max_nbtrcr,max_blocks), public :: &
         flux_bio_atm  ! all bio fluxes to ice from atmosphere

      ! in from ocean

      real (kind=dbl_kind), &
         dimension (nx_block,ny_block,max_aero,max_blocks), public :: &
         faero_ocn   ! aerosol flux to ocean  (kg/m^2/s)

      ! out to ocean 

      real (kind=dbl_kind), &
         dimension (nx_block,ny_block,max_nbtrcr,max_blocks), public :: &
         flux_bio   , & ! all bio fluxes to ocean
         flux_bio_ai    ! all bio fluxes to ocean, averaged over grid cell

      real (kind=dbl_kind), dimension (nx_block,ny_block,max_blocks), public :: &
         fzsal_ai, & ! salt flux to ocean from zsalinity (kg/m^2/s) 
         fzsal_g_ai  ! gravity drainage salt flux to ocean (kg/m^2/s) 

      ! internal

      logical (kind=log_kind), public :: &
         cpl_bgc         ! switch to couple BGC via drivers

      real (kind=dbl_kind), dimension (nx_block,ny_block,ncat,max_blocks), public :: &
         hin_old     , & ! old ice thickness
         dsnown          ! change in snow thickness in category n (m)

      real (kind=dbl_kind), dimension (nx_block,ny_block,max_blocks), public :: &
         nit        , & ! ocean nitrate (mmol/m^3)          
         amm        , & ! ammonia/um (mmol/m^3)
         sil        , & ! silicate (mmol/m^3)
         dmsp       , & ! dmsp (mmol/m^3)
         dms        , & ! dms (mmol/m^3)
         hum        , & ! humic material carbon (mmol/m^3)
         fnit       , & ! ice-ocean nitrate flux (mmol/m^2/s), positive to ocean
         famm       , & ! ice-ocean ammonia/um flux (mmol/m^2/s), positive to ocean
         fsil       , & ! ice-ocean silicate flux (mmol/m^2/s), positive to ocean
         fdmsp      , & ! ice-ocean dmsp (mmol/m^2/s), positive to ocean
         fdms       , & ! ice-ocean dms (mmol/m^2/s), positive to ocean
         fhum       , & ! ice-ocean humic material carbon (mmol/m^2/s), positive to ocean
         fdust          ! ice-ocean dust flux (kg/m^2/s), positive to ocean

      real (kind=dbl_kind), dimension (nx_block,ny_block,max_algae, max_blocks), public :: &
         algalN     , & ! ocean algal nitrogen (mmol/m^3) (diatoms, pico, phaeo)
         falgalN        ! ice-ocean algal nitrogen flux (mmol/m^2/s) (diatoms, pico, phaeo)

      real (kind=dbl_kind), dimension (nx_block,ny_block,max_doc, max_blocks), public :: &
         doc         , & ! ocean doc (mmol/m^3)  (saccharids, lipids, tbd )
         fdoc            ! ice-ocean doc flux (mmol/m^2/s)  (saccharids, lipids, tbd)

      real (kind=dbl_kind), dimension (nx_block,ny_block,max_don, max_blocks), public :: &
         don         , & ! ocean don (mmol/m^3) (proteins and amino acids)
         fdon            ! ice-ocean don flux (mmol/m^2/s) (proteins and amino acids)

      real (kind=dbl_kind), dimension (nx_block,ny_block,max_dic, max_blocks), public :: &
         dic         , & ! ocean dic (mmol/m^3) 
         fdic            ! ice-ocean dic flux (mmol/m^2/s) 

      real (kind=dbl_kind), dimension (nx_block,ny_block,max_fe, max_blocks), public :: &
         fed, fep    , & ! ocean dissolved and particulate fe (nM) 
         ffed, ffep      ! ice-ocean dissolved and particulate fe flux (umol/m^2/s) 

      real (kind=dbl_kind), dimension (nx_block,ny_block,max_aero, max_blocks), public :: &
         zaeros          ! ocean aerosols (mmol/m^3) 

!=======================================================================

      contains

!=======================================================================

! Initialize some fluxes sent to coupler for use by the atm model
!
! author: Nicole Jeffery, LANL

      subroutine bgcflux_ice_to_ocn(nx_block,       &
                                  ny_block,         &
                                  flux_bio,         &
                                  f_nit,    f_sil,    &
                                  f_amm,    f_dmsp,   &
                                  f_dms,    f_hum,    &
                                  f_dust,   f_algalN, &
                                  f_doc,    f_dic,    &
                                  f_don,    f_fep,    &
                                  f_fed)

      use icepack_intfc_shared, only: skl_bgc, solve_zbgc
      use icepack_intfc_tracers, only: nlt_bgc_N, nlt_bgc_C, nlt_bgc_DOC, nlt_bgc_DON, &
          nlt_bgc_DIC, nlt_bgc_Fed, nlt_bgc_Fep, nlt_zaero, nlt_bgc_Nit, nlt_bgc_Am, &
          nlt_bgc_Sil, nlt_bgc_DMSPd, nlt_bgc_DMS, nlt_bgc_hum, tr_bgc_Nit, tr_bgc_N, &
          tr_bgc_DON, tr_bgc_C, tr_bgc_Am, tr_bgc_Sil, tr_bgc_DMS, tr_bgc_Fe, &
          tr_bgc_hum, tr_zaero
      use ice_constants, only: c0
      use ice_domain_size, only: n_zaero, n_algae, n_doc, n_dic, n_don, n_fed, n_fep
    
      real(kind=dbl_kind), dimension(:,:,:), intent(in) :: flux_bio
      real(kind=dbl_kind), dimension(:,:), intent(out):: &
          f_nit,  &  ! nitrate flux mmol/m^2/s  positive to ocean
          f_sil,  &  ! silicate flux mmol/m^2/s
          f_amm,  &  ! ammonium flux mmol/m^2/s
          f_dmsp, &  ! DMSPd flux mmol/m^2/s
          f_dms,  &  ! DMS flux mmol/m^2/s
          f_hum,  &  ! humic flux mmol/m^2/s
          f_dust     ! dust flux kg/m^2/s

      real(kind=dbl_kind), dimension(:,:,:), intent(out):: &
          f_algalN, & ! algal nitrogen flux mmol/m^2/s
          f_doc,    & ! DOC flux mmol/m^2/s
          f_dic,    & ! DIC flux mmol/m^2/s
          f_don,    & ! DON flux mmol/m^2/s
          f_fep,    & ! particulate iron flux umol/m^2/s
          f_fed       ! dissolved iron flux umol/m^2/s

      integer (kind=int_kind), intent(in) :: &
          nx_block, &
          ny_block

      ! local variables

      integer (kind=int_kind) :: & 
         i,j         , & ! horizontal indices
         k               ! tracer index
   
      f_nit    (:,:) = c0
      f_sil    (:,:) = c0
      f_amm    (:,:) = c0
      f_dmsp   (:,:) = c0
      f_dms    (:,:) = c0
      f_hum    (:,:) = c0
      f_dust   (:,:) = c0
      f_algalN(:,:,:)= c0
      f_doc   (:,:,:)= c0
      f_dic   (:,:,:)= c0
      f_don   (:,:,:)= c0
      f_fep   (:,:,:)= c0
      f_fed   (:,:,:)= c0

      do j = 1, ny_block
      do i = 1, nx_block
         if (skl_bgc .or. solve_zbgc) then
            do k = 1, n_algae
               f_algalN(i,j,k) = flux_bio(i,j,nlt_bgc_N(k))
            enddo
         endif
         if (tr_bgc_C) then
            do k = 1, n_doc
               f_doc(i,j,k) = flux_bio(i,j,nlt_bgc_DOC(k))
            enddo
            do k = 1, n_dic
               f_dic(i,j,k) = flux_bio(i,j,nlt_bgc_DIC(k))
            enddo
         endif
         if (tr_bgc_DON) then
            do k = 1, n_don
               f_don(i,j,k) = flux_bio(i,j,nlt_bgc_DON(k))
            enddo
         endif
         if (tr_bgc_Fe) then
            do k = 1, n_fep
               f_fep(i,j,k) = flux_bio(i,j,nlt_bgc_Fep(k))
            enddo
            do k = 1, n_fed
               f_fed(i,j,k) = flux_bio(i,j,nlt_bgc_Fed(k))
            enddo
         endif
         if (tr_bgc_Nit) f_nit(i,j)  = flux_bio(i,j,nlt_bgc_Nit)
         if (tr_bgc_Sil) f_sil(i,j)  = flux_bio(i,j,nlt_bgc_Sil)
         if (tr_bgc_Am)  f_amm(i,j)  = flux_bio(i,j,nlt_bgc_Am)
         if (tr_bgc_hum) f_hum(i,j)  = flux_bio(i,j,nlt_bgc_hum)
         if (tr_bgc_DMS) then
            f_dms(i,j) = flux_bio(i,j,nlt_bgc_DMS)
            f_dmsp(i,j) = flux_bio(i,j,nlt_bgc_DMSPd)
         endif
         if (tr_zaero) then
            do k = 3, n_zaero
                f_dust(i,j) = f_dust(i,j) + flux_bio(i,j,nlt_zaero(k))
            enddo
         endif
      enddo
      enddo

      end subroutine bgcflux_ice_to_ocn

!=======================================================================

      end module ice_flux_bgc

!=======================================================================
