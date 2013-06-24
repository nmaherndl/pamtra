module constants
    ! Description:
    ! Definition of all constants for pamtra
    !
    ! History:
    ! Version   Date     Comment
    ! -------   ----     -------
    !  0.1   17/11/2009    creation of file

    use kinds, only: dbl

    implicit none
    save

    real(kind=dbl), parameter :: c = 299792458_dbl
    real(kind=dbl), parameter :: pi = 3.141592653589793_dbl
    real(kind=dbl), parameter :: t_abs = 273.15_dbl
    real(kind=dbl), parameter :: g = 9.80665_dbl
    real(kind=dbl), parameter :: sky_temp = 2.73_dbl
    real(kind=dbl), parameter :: rho_water = 1000_dbl
    real(kind=dbl), parameter :: rho_ice = 916.7_dbl

    real(kind=dbl), parameter :: tpt = 273.16_dbl               ! triple point temperature
    real(kind=dbl), parameter :: estpt = 611.14_dbl             ! saturation vapor triple point temperature
    real(kind=dbl), parameter :: mmd = 28.9644d-3               ! molar mass of dry air
    real(kind=dbl), parameter :: mmv = 18.0153d-3               ! molar mass of vapor
    real(kind=dbl), parameter :: k_b = 1.380658d-23             ! Boltzman constant
    real(kind=dbl), parameter :: n_a = 6.0221367d+23            ! Avogadro number
    real(kind=dbl), parameter :: r_d = 287.0596736665907_dbl    ! gas constant of dry air
    real(kind=dbl), parameter :: r_v = 461.5249933083879_dbl    ! gas constant of water vapor
    real(kind=dbl), parameter :: vapor_hc  = 2.5008d+6          ! vaporization heat constant
    real(kind=dbl), parameter :: sublim_hc  = 2.8345d+6         ! sublimation heat constant

    real(kind=dbl), parameter :: delta_d_mono  = 1.d-8          ! delta diameter used for monodisperse drop-size distribution

    complex(kind=dbl), parameter :: im = (0.0_dbl, 1.0_dbl)

end module constants
