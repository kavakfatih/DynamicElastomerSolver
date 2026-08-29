!> ---------------------------------------------------------------------------
!> check_elem_axi_q4 -- VER-032: eksenel simetrik Q4 elemanı doğrulaması
!>
!> Çözücü henüz yok; dolayısıyla yama testi (patch test) BU TESTTE YOKTUR --
!> o, Newton ile birlikte v0.1'de gelecek. Buradaki kontrollerin hepsi
!> eleman düzeyindedir ve çözücüsüz yapılabilir.
!>
!>   E1. Tanjant, artığın sonlu farkına karşı  (bu oturumun KAPISI)
!>   E2. Homojen deformasyon, analitik referans
!>   E3. Rijit cisim hareketi -> sıfır gerilme
!>   E4. Eksen üzerindeki düğüm
!>   E5. quality()
!>
!> E3 HAKKINDA BİR DÜZELTME
!>
!> Eksenel simetride, burulma serbestliği olmadan, TEK rijit cisim hareketi
!> EKSENEL ÖTELEMEdir:
!>
!>   - z ötelemesi : u_z = sabit -> F = I. Rijit. TEST EDİLİYOR.
!>   - r ötelemesi : u_r = sabit -> F_tt = 1 + c/R /= 1. RİJİT DEĞİL,
!>                   ayrıca eksenel simetriyi de bozar.
!>   - r-z düzleminde dönme : u_r yarıçapa göre değişir -> F_tt /= 1.
!>                   RİJİT DEĞİL. Bu, spesifikasyonun da işaret ettiği
!>                   tuzaktır.
!>   - z ekseni etrafında dönme : gerçek rijit harekettir ama yer
!>                   değiştirmesi u_theta'dadır; bu eleman u_theta
!>                   taşımaz (v0.2). Temsil edilemez, dolayısıyla
!>                   sınanamaz.
!>
!> Bu yüzden E3 yalnızca eksenel ötelemeyi sınar ve r-z dönmesini BİLİNÇLİ
!> OLARAK sınamaz; onun sıfır gerilme vermesi beklenmez ve beklenmemelidir.
!> Test bunun yerine dönmenin gerçekten sıfırdan farklı gerilme ürettiğini
!> gösterir -- yanlış bir beklentiyi kayıt altına almak için.
!> ---------------------------------------------------------------------------
program check_elem_axi_q4
   use, intrinsic :: ieee_arithmetic, only: ieee_is_nan
   use des_kinds, only: dp, ip
   use des_tensor, only: det3, cauchy_from_pk2
   use des_material, only: material_state_t
   use des_mat_neohookean, only: mat_neohookean_t, new_neohookean
   use des_element, only: element_config_t, element_ctx_t, element_quality_t, &
                          DES_ELEM_OK, DES_ELEM_BAD_ARG, &
                          DES_ANA_AXISYM, DES_FORM_FULL, DES_FORM_FBAR, &
                          DES_FORM_MIXED_UP, DES_ELEM_UNSUPPORTED
   use des_elem_axi_q4, only: elem_axi_q4_t, new_axi_q4
   use test_support, only: t_begin, t_check_le, t_check_true, t_check_int, &
                           t_info, t_finish
   implicit none

   real(dp), parameter :: C10 = 0.6_dp
   real(dp), parameter :: KBULK = 1.0e5_dp

   !> E1 merkezi fark adımı. Malzeme tanjantındaki (VER-002) ile aynı
   !> gerekçe: h^2 kesme hatası ile eps/h yuvarlama hatasının dengelendiği
   !> bölge.
   real(dp), parameter :: FD_STEP = 1.0e-6_dp

   !> E1 toleransı. Yuvarlama tabanı ~1e-10 beklenir; iki mertebe pay.
   real(dp), parameter :: TOL_TANGENT = 1.0e-8_dp
   !> Major simetri analitik olarak tam; sapma yalnızca toplama sırasından.
   real(dp), parameter :: TOL_MAJSYM = 1.0e-10_dp

   !> E2 toleransı. Homojen deformasyonda AYRIKLAŞTIRMA HATASI YOKTUR;
   !> sapma varsa kinematik yanlıştır. Kalan tek kaynak yuvarlamadır.
   real(dp), parameter :: TOL_HOMOG = 1.0e-9_dp

   type(mat_neohookean_t)  :: mat
   type(element_config_t)  :: cfg
   type(element_ctx_t)     :: ctx
   type(elem_axi_q4_t)     :: el
   type(element_quality_t) :: q
   type(material_state_t)  :: sn(4), snp1(4)

   real(dp) :: nodes(2, 4), u(2, 4), ug(1), f_int(2, 4), fg(1)
   real(dp) :: K_uu(8, 8), K_ug(8, 1), K_gg(1, 1)
   real(dp) :: sig(3, 3), err, maxk
   integer(ip) :: stat, g

   call t_begin('VER-032  Eksenel simetrik Q4  (ADR-0009 ilk uygulama)')

   mat = new_neohookean(C10, KBULK)
   do g = 1_ip, 4_ip
      call sn(g)%init(0_ip)
      call snp1(g)%init(0_ip)
   end do

   !> Eksenden UZAK birim kare: R = 1..2, Z = 0..1
   nodes = reshape([1.0_dp, 0.0_dp, 2.0_dp, 0.0_dp, &
                    2.0_dp, 1.0_dp, 1.0_dp, 1.0_dp], [2, 4])

   ! =========================================================================
   ! 0 -- Kurulum ve desteklenmeyen formulasyon
   ! =========================================================================
   call t_info('')
   call t_info(' 0. Kurulum')

   cfg%analysis = DES_ANA_AXISYM
   cfg%formulation = DES_FORM_FULL
   cfg%n_gauss = 4_ip
   el = new_axi_q4(7_ip)
   call el%setup(nodes, cfg, mat, stat)
   call t_check_int('full     : setup OK', stat, DES_ELEM_OK)
   call t_check_int('DOF/dugum = 2', el%n_dof_per_node(), 2_ip)
   call t_check_int('dugum sayisi = 4', el%n_node(), 4_ip)
   call t_check_int('global DOF = 0', el%n_global_dof(), 0_ip)

   cfg%formulation = DES_FORM_MIXED_UP
   call el%setup(nodes, cfg, mat, stat)
   call t_check_int('mixed_up : DES_ELEM_UNSUPPORTED', stat, DES_ELEM_UNSUPPORTED)

   !> Ters dugum sirasi bir AG HATASIDIR; setup reddetmeli.
   cfg%formulation = DES_FORM_FULL
   call el%setup(reshape([1.0_dp, 0.0_dp, 1.0_dp, 1.0_dp, &
                          2.0_dp, 1.0_dp, 2.0_dp, 0.0_dp], [2, 4]), &
                 cfg, mat, stat)
   call t_check_int('ters dugum sirasi reddedildi', stat, DES_ELEM_BAD_ARG)

   ! =========================================================================
   ! E1 -- TANJANT vs REZIDUNUN SONLU FARKI   (KAPI)
   ! =========================================================================
   call t_info('')
   call t_info(' E1. Tanjant, artigin merkezi farkina karsi')

   call run_tangent_check(DES_FORM_FULL, 'full ')
   call run_tangent_check(DES_FORM_FBAR, 'fbar ')

   ! =========================================================================
   ! E2 -- HOMOJEN DEFORMASYON
   ! =========================================================================
   call t_info('')
   call t_info(' E2. Homojen deformasyon, analitik referans')

   cfg%formulation = DES_FORM_FULL
   call el%setup(nodes, cfg, mat, stat)

   call t_info('   (a) duzgun uc eksenli genisleme F = diag(1.1,1.1,1.1)')
   call homogeneous_stress(1.1_dp, 1.1_dp, sig, stat)
   call t_check_int('(a) eval OK', stat, DES_ELEM_OK)
   write (*, '(a,3(2x,f18.9))') '       sigma_rr, zz, tt = ', &
      sig(1, 1), sig(2, 2), sig(3, 3)
   call t_check_le('(a) sigma_rr = 33100.0', &
                   abs(sig(1, 1) - 33100.0_dp)/33100.0_dp, TOL_HOMOG)
   call t_check_le('(a) sigma_zz = 33100.0', &
                   abs(sig(2, 2) - 33100.0_dp)/33100.0_dp, TOL_HOMOG)
   call t_check_le('(a) sigma_tt = 33100.0', &
                   abs(sig(3, 3) - 33100.0_dp)/33100.0_dp, TOL_HOMOG)
   call t_check_le('(a) izotropiden sapma = 0', &
                   abs(sig(1, 1) - sig(2, 2)) + abs(sig(1, 1) - sig(3, 3)), &
                   0.0_dp)

   call t_info('   (b) radyal uzama F = diag(1.2, 1.0, 1.2)')
   call homogeneous_stress(1.2_dp, 1.0_dp, sig, stat)
   write (*, '(a,3(2x,f18.9))') '       sigma_rr, zz, tt = ', &
      sig(1, 1), sig(2, 2), sig(3, 3)
   call t_check_le('(b) sigma_rr = 44000.095846262', &
                   abs(sig(1, 1) - 44000.095846262_dp)/44000.0_dp, TOL_HOMOG)
   call t_check_le('(b) sigma_zz = 43999.808307476', &
                   abs(sig(2, 2) - 43999.808307476_dp)/44000.0_dp, TOL_HOMOG)
   call t_check_le('(b) sigma_tt = 44000.095846262', &
                   abs(sig(3, 3) - 44000.095846262_dp)/44000.0_dp, TOL_HOMOG)
   call t_check_le('(b) sigma_rr = sigma_tt tam', &
                   abs(sig(1, 1) - sig(3, 3)), 0.0_dp)

   call t_info('   (c) izokorik eksenel uzama, lambda_z = 1.5, J = 1')
   call homogeneous_stress(1.5_dp**(-0.5_dp), 1.5_dp, sig, stat)
   write (*, '(a,3(2x,f18.9))') '       sigma_rr, zz, tt = ', &
      sig(1, 1), sig(2, 2), sig(3, 3)
   call t_check_le('(c) sigma_zz = 1.266666667', &
                   abs(sig(2, 2) - 1.2666666666666666_dp)/1.2666_dp, TOL_HOMOG)
   call t_check_le('(c) sigma_rr = -0.633333333', &
                   abs(sig(1, 1) + 0.6333333333333333_dp)/0.6333_dp, TOL_HOMOG)
   call t_check_le('(c) sigma_zz - sigma_rr = 1.9  (VER-001 caprazi)', &
                   abs((sig(2, 2) - sig(1, 1)) - 1.9_dp)/1.9_dp, TOL_HOMOG)

   ! =========================================================================
   ! E3 -- RIJIT CISIM HAREKETI
   ! =========================================================================
   call t_info('')
   call t_info(' E3. Rijit cisim hareketi  (eksenel oteleme)')

   u = 0.0_dp
   u(2, :) = 0.37_dp
   call el%residual(u, ug, ctx, sn, f_int, fg, snp1, stat, err)
   call t_check_int('eksenel oteleme: eval OK', stat, DES_ELEM_OK)
   write (*, '(a,es12.5)') '       max |f_int| = ', maxval(abs(f_int))
   call t_check_le('eksenel oteleme -> f_int = 0', maxval(abs(f_int)), 1.0e-11_dp)

   !> r-z duzleminde donme RIJIT DEGILDIR (F_tt degisir). Bunu kayit
   !> altina aliyoruz ki yanlis beklenti ileride kimseyi yaniltmasin.
   call rotate_rz(0.05_dp, u)
   call el%residual(u, ug, ctx, sn, f_int, fg, snp1, stat, err)
   write (*, '(a,es12.5)') '       r-z donmesi max |f_int| = ', maxval(abs(f_int))
   call t_check_true('r-z donmesi RIJIT DEGIL (f_int /= 0)', &
                     maxval(abs(f_int)) > 1.0e-6_dp)

   ! =========================================================================
   ! E4 -- EKSEN UZERINDEKI DUGUM
   ! =========================================================================
   call t_info('')
   call t_info(' E4. Eksen uzerindeki dugum  (R = 0)')

   call el%setup(reshape([0.0_dp, 0.0_dp, 1.0_dp, 0.0_dp, &
                          1.0_dp, 1.0_dp, 0.0_dp, 1.0_dp], [2, 4]), &
                 cfg, mat, stat)
   call t_check_int('eksen elemani: setup OK', stat, DES_ELEM_OK)

   call homogeneous_stress(1.1_dp, 1.1_dp, sig, stat)
   call t_check_int('eksen elemani: eval OK', stat, DES_ELEM_OK)
   write (*, '(a,3(2x,f18.9))') '       sigma_rr, zz, tt = ', &
      sig(1, 1), sig(2, 2), sig(3, 3)
   call t_check_le('eksen: sigma_rr = 33100.0 (E2a ile ayni)', &
                   abs(sig(1, 1) - 33100.0_dp)/33100.0_dp, TOL_HOMOG)
   !> NaN kontrolu: ieee_is_nan, esitlik karsilastirmasindan hem daha
   !> acik hem -Wcompare-reals uyarisi uretmiyor.
   call t_check_true('eksen: NaN yok', .not. ieee_is_nan(sig(1, 1)))
   call t_check_le('eksen: sigma_tt = sigma_rr', &
                   abs(sig(3, 3) - sig(1, 1))/33100.0_dp, TOL_HOMOG)

   !> Tanjant da eksen elemaninda saglam olmali (1/R orada sadelesmez).
   !> F-BAR ile: ortalama genlesme terimleri eksen elemaninda da dogru
   !> olmali. Once formulasyonu gercekten fbar'a cevir -- aksi halde
   !> etiket fbar der ama eleman full kalirdi.
   cfg%formulation = DES_FORM_FBAR
   call el%setup(reshape([0.0_dp, 0.0_dp, 1.0_dp, 0.0_dp, &
                          1.0_dp, 1.0_dp, 0.0_dp, 1.0_dp], [2, 4]), &
                 cfg, mat, stat)
   call t_check_int('eksen fbar: setup OK', stat, DES_ELEM_OK)
   call run_tangent_check_on(el, DES_FORM_FBAR, 'eksen')

   ! =========================================================================
   ! E5 -- quality()
   ! =========================================================================
   call t_info('')
   call t_info(' E5. quality()')

   call el%setup(nodes, cfg, mat, stat)
   u = 0.0_dp
   call el%quality(u, q)
   call t_check_true('bozulmamis: implemented', q%implemented)
   call t_check_true('bozulmamis: inverted = false', .not. q%inverted)
   call t_check_le('bozulmamis: jacobian_ratio = 1', &
                   abs(q%jacobian_ratio - 1.0_dp), 1.0e-13_dp)
   call t_check_le('bozulmamis: aspect_ratio = 1', &
                   abs(q%aspect_ratio - 1.0_dp), 1.0e-13_dp)
   call t_check_le('bozulmamis: min aci = 90', abs(q%min_angle - 90.0_dp), 1.0e-11_dp)
   call t_check_le('bozulmamis: max aci = 90', abs(q%max_angle - 90.0_dp), 1.0e-11_dp)
   call t_check_le('bozulmamis: worst = 1', abs(q%worst - 1.0_dp), 1.0e-13_dp)

   !> Elemani katlayarak ters cevir: 3. dugumu karsi kosenin otesine tasi.
   u = 0.0_dp
   u(1, 3) = -1.6_dp
   u(2, 3) = -1.6_dp
   call el%quality(u, q)
   call t_check_true('katlanmis eleman: inverted = true', q%inverted)
   call t_check_le('katlanmis eleman: worst = 0', q%worst, 0.0_dp)

   write (*, '(a)') ''
   call t_finish()

contains

   !> Homojen bir F dayat; ELEMANIN her Gauss noktasinda gordugu F'yi ve
   !> gerilmeyi topla.
   !>
   !> u_r = (F_rr - 1) R  ve  u_z = (F_zz - 1) Z  alinirsa hem
   !> du_r/dR = F_rr - 1 hem u_r/R = F_rr - 1 olur; yani F_tt = F_rr.
   !> E2'nin uc vakasi da bu ailededir.
   !>
   !> DIKKAT: gerilme ELEMANDAN alinir, malzemeden dogrudan DEGIL.
   !> Aksi hâlde test yalnizca malzemeyi dogrular, elemanin kinematigini
   !> hic sinamaz.
   subroutine homogeneous_stress(frr, fzz, sig_out, stat_out)
      real(dp), intent(in) :: frr, fzz
      real(dp), intent(out) :: sig_out(3, 3)
      integer(ip), intent(out) :: stat_out

      !> `Fgp` adi bilincli: `Fg`, host kapsamindaki fg(1) global
      !> kuvvet dizisini maskelerdi (Fortran harf duyarsizdir).
      real(dp) :: uu(2, 4), Fgp(3, 3), sg(3, 3), Fexp(3, 3)
      real(dp) :: dF_max, dS_max
      integer(ip) :: a, gp, st

      do a = 1_ip, 4_ip
         uu(1, a) = (frr - 1.0_dp)*el%XR(a)
         uu(2, a) = (fzz - 1.0_dp)*el%XZ(a)
      end do

      Fexp = 0.0_dp
      Fexp(1, 1) = frr
      Fexp(2, 2) = fzz
      Fexp(3, 3) = frr

      sig_out = 0.0_dp
      stat_out = DES_ELEM_BAD_ARG
      dF_max = 0.0_dp
      dS_max = 0.0_dp

      !> HER Gauss noktasi tam olarak dayatilan F'yi gormeli.
      do gp = 1_ip, 4_ip
         call el%gauss_state(uu, gp, Fgp, sg, st)
         if (st /= DES_ELEM_OK) return
         dF_max = max(dF_max, maxval(abs(Fgp - Fexp)))
         if (gp == 1_ip) then
            sig_out = sg
         else
            dS_max = max(dS_max, maxval(abs(sg - sig_out)))
         end if
      end do

      write (*, '(a,es11.4,a,es11.4)') &
         '       Gauss noktalari arasinda  max|dF| = ', dF_max, &
         '   max|dsigma| = ', dS_max
      call t_check_le('  her Gauss noktasi ayni F', dF_max, 1.0e-14_dp)
      call t_check_le('  her Gauss noktasi ayni sigma', dS_max, 1.0e-9_dp)

      stat_out = DES_ELEM_OK
   end subroutine homogeneous_stress

   !> r-z duzleminde kucuk bir donme uygula.
   subroutine rotate_rz(ang, uu)
      real(dp), intent(in) :: ang
      real(dp), intent(out) :: uu(2, 4)

      real(dp) :: c, s
      integer(ip) :: a

      c = cos(ang)
      s = sin(ang)
      do a = 1_ip, 4_ip
         uu(1, a) = c*el%XR(a) - s*el%XZ(a) - el%XR(a)
         uu(2, a) = s*el%XR(a) + c*el%XZ(a) - el%XZ(a)
      end do
   end subroutine rotate_rz

   subroutine run_tangent_check(form, tag)
      integer(ip), intent(in) :: form
      character(len=*), intent(in) :: tag

      integer(ip) :: st

      cfg%formulation = form
      call el%setup(nodes, cfg, mat, st)
      if (st /= DES_ELEM_OK) then
         write (*, '(a,i0)') '   setup basarisiz, stat = ', st
         error stop 2
      end if
      call run_tangent_check_on(el, form, tag)
   end subroutine run_tangent_check

   !> K_uu'yu f_int'in merkezi farkina karsi dogrula.
   subroutine run_tangent_check_on(elem, form, tag)
      type(elem_axi_q4_t), intent(inout) :: elem
      integer(ip), intent(in) :: form
      character(len=*), intent(in) :: tag

      real(dp) :: uu(2, 4), fp(2, 4), fm(2, 4)
      real(dp) :: Kn(8, 8), Ka(8, 8)
      real(dp) :: dtf, sym
      character(len=34) :: label
      integer(ip) :: a, i, col, st

      !> Belirlenimci, HOMOJEN OLMAYAN bir yer degistirme alani: homojen
      !> bir alanda F-bar'in ek terimi kaybolur ve test onu sinamaz.
      uu(1, :) = [0.030_dp, 0.055_dp, 0.020_dp, -0.015_dp]
      uu(2, :) = [-0.020_dp, 0.018_dp, 0.062_dp, 0.041_dp]

      call elem%tangent(uu, ug, ctx, sn, K_uu, K_ug, K_gg, st)
      if (st /= DES_ELEM_OK) then
         write (*, '(a,i0)') '   tangent basarisiz, stat = ', st
         error stop 3
      end if
      Ka = K_uu

      do a = 1_ip, 4_ip
         do i = 1_ip, 2_ip
            col = (a - 1_ip)*2_ip + i

            uu(i, a) = uu(i, a) + FD_STEP
            call elem%residual(uu, ug, ctx, sn, fp, fg, snp1, st, dtf)
            if (st /= DES_ELEM_OK) error stop 4

            uu(i, a) = uu(i, a) - 2.0_dp*FD_STEP
            call elem%residual(uu, ug, ctx, sn, fm, fg, snp1, st, dtf)
            if (st /= DES_ELEM_OK) error stop 5

            uu(i, a) = uu(i, a) + FD_STEP

            Kn(:, col) = reshape((fp - fm)/(2.0_dp*FD_STEP), [8])
         end do
      end do

      maxk = maxval(abs(Ka))
      err = maxval(abs(Kn - Ka))/maxk
      sym = maxval(abs(Ka - transpose(Ka)))/maxk

      label = tag//': K_uu vs sonlu fark'
      call t_check_le(label, err, TOL_TANGENT)
      label = tag//': K_uu major simetri'
      call t_check_le(label, sym, TOL_MAJSYM)

      associate (unused => form)
      end associate
   end subroutine run_tangent_check_on

end program check_elem_axi_q4
