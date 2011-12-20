SUBROUTINE INITIALIZE (NSTOKES, NUMMU, N, DELTA_Z, MU_VALUES,     &
     EXTINCTION, ALBEDO, PHASE_FUNCTION, REFLECT, TRANS)               
  !        INITIALIZE performs infinitesimal generator initialization     
  !      to make the local reflection and transmission matrices from      
  !      the phase function matrix, extinction, and albedo.               
  !      The thickness of the layer is specified by DELTA_Z.      
  use kinds
  INTEGER NSTOKES, NUMMU, N 
  REAL(kind=dbl) DELTA_Z, MU_VALUES (NUMMU) 
  REAL(kind=dbl) EXTINCTION, ALBEDO 
  REAL(kind=dbl) PHASE_FUNCTION (N, N, 4) 
  REAL(kind=dbl) REFLECT (N, N, 2) 
  REAL(kind=dbl) TRANS (N, N, 2) 
  INTEGER I, J, K 
  REAL(kind=dbl) TMP, DIAG 


  DO I = 1, N 
     K = MOD ( (I - 1) / NSTOKES, NUMMU) + 1
     TMP = DELTA_Z / MU_VALUES (K) 
     DO J = 1, N 
        DIAG = 0.0 
        IF (J.EQ.I) DIAG = 1.0 
        REFLECT (I, J, 1) = TMP * EXTINCTION * ALBEDO * PHASE_FUNCTION (I, J, 2)
        TRANS (I, J, 1) = DIAG - TMP * EXTINCTION * (DIAG - ALBEDO * PHASE_FUNCTION (I, J, 1) )
        REFLECT (I, J, 2) = TMP * EXTINCTION * ALBEDO * PHASE_FUNCTION (I, J, 3)
        TRANS (I, J, 2) = DIAG - TMP * EXTINCTION * (DIAG - ALBEDO * PHASE_FUNCTION (I, J, 4) )
     ENDDO
  ENDDO

  RETURN 
END SUBROUTINE INITIALIZE


SUBROUTINE INITIAL_SOURCE (NSTOKES, NUMMU, N, DELTA_Z, MU_VALUES, &
     EXTINCTION, SOURCE_VECTOR, SOURCE)                                
  !        INITIAL_SOURCE performs infinitesimal generator initialization 
  !      for source vectors.         
  use kinds
  INTEGER NSTOKES, NUMMU, N 
  REAL(kind=dbl) DELTA_Z, MU_VALUES (NUMMU) 
  REAL(kind=dbl) EXTINCTION, SOURCE_VECTOR (N, 2) 
  REAL(kind=dbl) SOURCE (N, 2) 
  INTEGER I, K 
  REAL(kind=dbl) TMP 

  DO I = 1, N 
     K = MOD ( (I - 1) / NSTOKES, NUMMU) + 1 
     TMP = DELTA_Z / MU_VALUES (K) 
     SOURCE (I, 1) = TMP * EXTINCTION * SOURCE_VECTOR (I, 1) 
     SOURCE (I, 2) = TMP * EXTINCTION * SOURCE_VECTOR (I, 2) 
  ENDDO

  RETURN 
END SUBROUTINE INITIAL_SOURCE


SUBROUTINE NONSCATTER_LAYER (NSTOKES, NUMMU, MODE, DELTATAU,      &
     MU_VALUES, PLANCK0, PLANCK1, REFLECT, TRANS, SOURCE)              
  !        NONSCATTER_LAYER calculates the reflection and transmission    
  !      matrices and the source vectors for a purely absorbing layer.    
  !      The source function, which is the Planck function, is assumed    
  !      to vary linearly with optical depth across the layer. 
  use kinds
  INTEGER NSTOKES, NUMMU, MODE 
  REAL(kind=dbl) DELTATAU, MU_VALUES (NUMMU), PLANCK0, PLANCK1 
  REAL(kind=dbl) REFLECT (NSTOKES, NUMMU, NSTOKES, NUMMU, 2) 
  REAL(kind=dbl) TRANS (NSTOKES, NUMMU, NSTOKES, NUMMU, 2) 
  REAL(kind=dbl) SOURCE (NSTOKES, NUMMU, 2) 
  INTEGER N, I, J 
  REAL(kind=dbl) FACTOR, SLOPE, PATH 

  N = NSTOKES * NUMMU 
  CALL MZERO (2 * N, N, REFLECT) 

  CALL MZERO (2 * N, N, TRANS) 
  DO J = 1, NUMMU 
     FACTOR = DEXP ( - DELTATAU / MU_VALUES (J) ) 
     DO I = 1, NSTOKES
        TRANS (I, J, I, J, 1) = FACTOR 
        TRANS (I, J, I, J, 2) = FACTOR
     ENDDO
  ENDDO

  CALL MZERO (2 * N, 1, SOURCE) 
  IF (MODE.EQ.0.AND.DELTATAU.GT.0.0) THEN 
     DO J = 1, NUMMU 
        PATH = DELTATAU / MU_VALUES (J) 
        SLOPE = (PLANCK1 - PLANCK0) / PATH 
        SOURCE (1, J, 1) = PLANCK1 - SLOPE- (PLANCK1 - SLOPE * (1.0 + PATH) ) * DEXP( - PATH)
        SOURCE (1, J, 2) = PLANCK0 + SLOPE- (PLANCK0 + SLOPE * (1.0 + PATH) ) * DEXP( - PATH)
     ENDDO
  ENDIF

  RETURN 
END SUBROUTINE NONSCATTER_LAYER


SUBROUTINE INTERNAL_RADIANCE (N, UPREFLECT, UPTRANS, UPSOURCE,    &
     DOWNREFLECT, DOWNTRANS, DOWNSOURCE, INTOPRAD, INBOTTOMRAD, UPRAD, &
     DOWNRAD)                                                          
  !        INTERNAL_RADIANCE calculates the internal radiance at a level. 
  !      The reflection and transmission matrices and source vector are   
  !      given for the atmosphere above (UP) and below (DOWN) the level.  
  !      The upwelling and downwelling radiance are computed from the     
  !      two layer properties and the radiance incident on the top and bot
  use kinds
  INTEGER N 
  REAL(kind=dbl) UPREFLECT (N, N, 2), DOWNREFLECT (N, N, 2) 
  REAL(kind=dbl) UPTRANS (N, N, 2), DOWNTRANS (N, N, 2) 
  REAL(kind=dbl) UPSOURCE (N, 2), DOWNSOURCE (N, 2) 
  REAL(kind=dbl) INTOPRAD (N), INBOTTOMRAD (N) 
  REAL(kind=dbl) UPRAD (N), DOWNRAD (N) 
  INTEGER MAXV, MAXM 
  PARAMETER (MAXV = 64, MAXM = 4096) 
  REAL(kind=dbl) S (MAXV), V (MAXV) 
  REAL(kind=dbl) X (MAXM), Y (MAXM) 
  COMMON / SCRATCH1 / X, Y 


  !               Compute gamma plus                                      
  CALL MMULT (N, N, N, UPREFLECT (1, 1, 1), DOWNREFLECT (1, 1, 2),X)
  CALL MIDENTITY (N, Y) 
  CALL MSUB (N, N, Y, X, Y) 
  CALL MINVERT (N, Y, X) 
  !               Calculate the internal downwelling (plus) radiance vector
  CALL MMULT (N, N, 1, DOWNTRANS (1, 1, 2), INBOTTOMRAD, V) 
  CALL MMULT (N, N, 1, UPREFLECT (1, 1, 1), V, S) 
  CALL MMULT (N, N, 1, UPTRANS (1, 1, 1), INTOPRAD, V) 
  CALL MADD (N, 1, V, S, S) 
  CALL MMULT (N, N, 1, UPREFLECT (1, 1, 1), DOWNSOURCE (1, 2),V)
  CALL MADD (N, 1, V, S, S) 
  CALL MADD (N, 1, UPSOURCE (1, 1), S, S) 
  CALL MMULT (N, N, 1, X, S, DOWNRAD) 

  !               Compute gamma minus                                     
  CALL MMULT (N, N, N, DOWNREFLECT (1, 1, 2), UPREFLECT (1, 1, 1),X)
  CALL MIDENTITY (N, Y) 
  CALL MSUB (N, N, Y, X, Y) 
  CALL MINVERT (N, Y, X) 
  !               Calculate the internal upwelling (minus) radiance vector
  CALL MMULT (N, N, 1, UPTRANS (1, 1, 1), INTOPRAD, V) 
  CALL MMULT (N, N, 1, DOWNREFLECT (1, 1, 2), V, S) 
  CALL MMULT (N, N, 1, DOWNTRANS (1, 1, 2), INBOTTOMRAD, V) 
  CALL MADD (N, 1, V, S, S) 
  CALL MMULT (N, N, 1, DOWNREFLECT (1, 1, 2), UPSOURCE (1, 1),V)
  CALL MADD (N, 1, V, S, S) 
  CALL MADD (N, 1, DOWNSOURCE (1, 2), S, S) 
  CALL MMULT (N, N, 1, X, S, UPRAD) 

  RETURN 
END SUBROUTINE INTERNAL_RADIANCE


SUBROUTINE DOUBLING_INTEGRATION (N, NUM_DOUBLES, SRC_CODE,        &
     SYMMETRIC, REFLECT, TRANS, EXP_SOURCE, EXPFACTOR, LIN_SOURCE,     &
     LINFACTOR, T_REFLECT, T_TRANS, T_SOURCE)                          
  !        DOUBLING_INTEGRATION integrates homogeneous thin layers using
  !      the doubling algorithm.  NUM_DOUBLES doubling steps are done.
  !      The initial reflection (REFLECT) and transmission (TRANS) matrices
  !      are input.  Depending on SRC_CODE linear (thermal) and exponential
  !      (solar) sources are doubled.  The EXP_SOURCE and LIN_SOURCE vectors
  !      are the source vectors at zero optical depth.  The EXPFACTOR is
  !      the single layer attenuation factor for the exponential source,
  !      while the LINFACTOR is the single layer slope for the linear source.
  !      The SYMMETRIC flag specifies whether the plus and minus parts
  !      of the reflection and transmission matrices are separately calculated
  !      or are assumed to be the same.  The integrated output is in
  !      T_REFLECT, T_TRANS, and T_SOURCE.

  use kinds
  INTEGER N, NUM_DOUBLES, SRC_CODE 
  LOGICAL SYMMETRIC 
  REAL(kind=dbl) REFLECT (N, N, 2), TRANS (N, N, 2) 
  REAL(kind=dbl) EXP_SOURCE (N, 2), EXPFACTOR 
  REAL(kind=dbl) LIN_SOURCE (N, 2), LINFACTOR 
  REAL(kind=dbl) T_REFLECT (N, N, 2), T_TRANS (N, N, 2) 
  REAL(kind=dbl) T_SOURCE (N, 2) 
  INTEGER MAXV, MAXM 
  PARAMETER (MAXV = 64, MAXM = 4096) 
  INTEGER I, NM 
  REAL(kind=dbl) T_EXP (2 * MAXV), T_LIN (2 * MAXV) 
  REAL(kind=dbl) CONST (2 * MAXV), T_CONST (2 * MAXV) 
  REAL(kind=dbl) EXPFAC, LINFAC 
  REAL(kind=dbl) X (MAXM), Y (MAXM) 
  REAL(kind=dbl) GAMMA (MAXM) 
  COMMON / SCRATCH1 / X, Y 
  COMMON / SCRATCH2 / GAMMA 

  EXPFAC = EXPFACTOR 
  LINFAC = LINFACTOR 
  CALL MCOPY (N, 1, LIN_SOURCE (1, 1), CONST (1) ) 
  CALL MCOPY (N, 1, LIN_SOURCE (1, 2), CONST (1 + N) ) 

  DO I = 1, NUM_DOUBLES 

     !           Make gamma plus matrix: GAMMA = inv[1 - Rp*Rm]              
     CALL MMULT (N, N, N, REFLECT (1, 1, 1), REFLECT (1, 1, 2),X)
     CALL MIDENTITY (N, Y) 
     CALL MSUB (N, N, Y, X, Y) 
     CALL MINVERT (N, Y, GAMMA) 

     !           Rp(2N) = Rp + Tp * GAMMA * Rp * Tm                          
     CALL MMULT (N, N, N, REFLECT (1, 1, 1), TRANS (1, 1, 2), X) 
     CALL MMULT (N, N, N, GAMMA, X, Y) 
     CALL MMULT (N, N, N, TRANS (1, 1, 1), Y, X) 
     CALL MADD (N, N, REFLECT (1, 1, 1), X, T_REFLECT (1, 1, 1) ) 

     !           Tp(2N) = Tp * GAMMA * Tp                                    
     CALL MMULT (N, N, N, GAMMA, TRANS (1, 1, 1), X) 
     CALL MMULT (N, N, N, TRANS (1, 1, 1), X, T_TRANS (1, 1, 1) ) 

     !           Exponential source doubling                                 
     IF (SRC_CODE.EQ.1.OR.SRC_CODE.EQ.3) THEN 
        !             Sp(2N) = e*Sp + Tp * GAMMA * (Sp + Rp * e*Sm)             
        CALL MSCALARMULT (N, 1, EXPFAC, EXP_SOURCE (1, 2), Y) 
        CALL MMULT (N, N, 1, REFLECT (1, 1, 1), Y, X) 
        CALL MADD (N, 1, EXP_SOURCE (1, 1), X, Y) 
        CALL MMULT (N, N, 1, GAMMA, Y, X) 
        CALL MMULT (N, N, 1, TRANS (1, 1, 1), X, Y) 
        CALL MSCALARMULT (N, 1, EXPFAC, EXP_SOURCE (1, 1), X) 
        CALL MADD (N, 1, X, Y, T_EXP (1) ) 
     ENDIF

     !           Linear source doubling                                      
     IF (SRC_CODE.GE.2) THEN 
        !             Sp(2N) = (Sp+f*Cp) + Tp * GAMMA * (Sp + Rp * (Sm+f*Cm))   
        CALL MSCALARMULT (N, 1, LINFAC, CONST (1 + N), X) 
        CALL MADD (N, 1, LIN_SOURCE (1, 2), X, Y) 
        CALL MMULT (N, N, 1, REFLECT (1, 1, 1), Y, X) 
        CALL MADD (N, 1, LIN_SOURCE (1, 1), X, Y) 
        CALL MMULT (N, N, 1, GAMMA, Y, X) 
        CALL MMULT (N, N, 1, TRANS (1, 1, 1), X, Y) 
        CALL MADD (N, 1, LIN_SOURCE (1, 1), Y, X) 
        CALL MSCALARMULT (N, 1, LINFAC, CONST (1), Y) 
        CALL MADD (N, 1, X, Y, T_LIN (1) ) 
        !             Cp(2N) = Cp + Tp * GAMMA * (Cp + Rp * Cm)                 
        CALL MMULT (N, N, 1, REFLECT (1, 1, 1), CONST (1 + N), X) 
        CALL MADD (N, 1, CONST (1), X, Y) 
        CALL MMULT (N, N, 1, GAMMA, Y, X) 
        CALL MMULT (N, N, 1, TRANS (1, 1, 1), X, Y) 
        CALL MADD (N, 1, CONST (1), Y, T_CONST (1) ) 
     ENDIF


     IF (SYMMETRIC) THEN 
        CALL MCOPY (N, N, T_REFLECT (1, 1, 1), T_REFLECT (1, 1, 2) ) 
        CALL MCOPY (N, N, T_TRANS (1, 1, 1), T_TRANS (1, 1, 2) ) 

     ELSE 
        !             Make gamma minus matrix: GAMMA = inv[1 - Rm*Rp]           
        CALL MMULT (N, N, N, REFLECT (1, 1, 2), REFLECT (1, 1, 1),     &
             X)                                                             
        CALL MIDENTITY (N, Y) 
        CALL MSUB (N, N, Y, X, Y) 
        CALL MINVERT (N, Y, GAMMA) 

        !             Rm(2N) = Rm + Tm * GAMMA * Rm * Tp                        
        CALL MMULT (N, N, N, REFLECT (1, 1, 2), TRANS (1, 1, 1),       &
             X)                                                             
        CALL MMULT (N, N, N, GAMMA, X, Y) 
        CALL MMULT (N, N, N, TRANS (1, 1, 2), Y, X) 
        CALL MADD (N, N, REFLECT (1, 1, 2), X, T_REFLECT (1, 1, 2) ) 

        !             Tm(2N) = Tm * GAMMA * Tm                                  
        CALL MMULT (N, N, N, GAMMA, TRANS (1, 1, 2), X) 
        CALL MMULT (N, N, N, TRANS (1, 1, 2), X, T_TRANS (1, 1, 2) ) 
     ENDIF


     !           Exponential source doubling                                 
     IF (SRC_CODE.EQ.1.OR.SRC_CODE.EQ.3) THEN 
        !             Sm(2N) = Sm + Tm * GAMMA * (e*Sm + Rm * Sp)               
        CALL MMULT (N, N, 1, REFLECT (1, 1, 2), EXP_SOURCE (1, 1),     &
             Y)                                                             
        CALL MSCALARMULT (N, 1, EXPFAC, EXP_SOURCE (1, 2), X) 
        CALL MADD (N, 1, X, Y, Y) 
        CALL MMULT (N, N, 1, GAMMA, Y, X) 
        CALL MMULT (N, N, 1, TRANS (1, 1, 2), X, Y) 
        CALL MADD (N, 1, EXP_SOURCE (1, 2), Y, T_EXP (1 + N) ) 

        CALL MCOPY (N, 1, T_EXP (1), EXP_SOURCE (1, 1) ) 
        CALL MCOPY (N, 1, T_EXP (1 + N), EXP_SOURCE (1, 2) ) 
        EXPFAC = EXPFAC**2 
     ENDIF

     !           Linear source doubling                                      
     IF (SRC_CODE.GE.2) THEN 
        !             Sm(2N) = Sm + Tm * GAMMA * (Sm+f*Cm + Rm * Sp)            
        CALL MSCALARMULT (N, 1, LINFAC, CONST (1 + N), X) 
        CALL MADD (N, 1, LIN_SOURCE (1, 2), X, Y) 
        CALL MMULT (N, N, 1, REFLECT (1, 1, 2), LIN_SOURCE (1, 1),     &
             X)                                                             
        CALL MADD (N, 1, Y, X, Y) 
        CALL MMULT (N, N, 1, GAMMA, Y, X) 
        CALL MMULT (N, N, 1, TRANS (1, 1, 2), X, Y) 
        CALL MADD (N, 1, LIN_SOURCE (1, 2), Y, T_LIN (1 + N) ) 
        !             Cm(2N) = Cm + Tm * GAMMA * (Cm + Rm * Cp)                 
        CALL MMULT (N, N, 1, REFLECT (1, 1, 2), CONST (1), X) 
        CALL MADD (N, 1, CONST (1 + N), X, Y) 
        CALL MMULT (N, N, 1, GAMMA, Y, X) 
        CALL MMULT (N, N, 1, TRANS (1, 1, 2), X, Y) 
        CALL MADD (N, 1, CONST (1 + N), Y, T_CONST (1 + N) ) 

        CALL MCOPY (N, 1, T_LIN (1), LIN_SOURCE (1, 1) ) 
        CALL MCOPY (N, 1, T_LIN (1 + N), LIN_SOURCE (1, 2) ) 
        CALL MCOPY (2 * N, 1, T_CONST, CONST) 
        LINFAC = 2.0 * LINFAC 
     ENDIF

     CALL MCOPY (N, N, T_REFLECT (1, 1, 1), REFLECT (1, 1, 1) ) 
     CALL MCOPY (N, N, T_REFLECT (1, 1, 2), REFLECT (1, 1, 2) ) 
     CALL MCOPY (N, N, T_TRANS (1, 1, 1), TRANS (1, 1, 1) ) 
     CALL MCOPY (N, N, T_TRANS (1, 1, 2), TRANS (1, 1, 2) ) 
  ENDDO

  NM = 2 * N 
  IF (NUM_DOUBLES.LE.0) THEN 
     CALL MCOPY (NM, N, REFLECT, T_REFLECT) 
     CALL MCOPY (NM, N, TRANS, T_TRANS) 
  ENDIF

  IF (SRC_CODE.EQ.3) THEN 
     CALL MADD (NM, 1, EXP_SOURCE, LIN_SOURCE, T_SOURCE) 
  ELSEIF (SRC_CODE.EQ.2) THEN 
     CALL MCOPY (NM, 1, LIN_SOURCE, T_SOURCE) 
  ELSEIF (SRC_CODE.EQ.1) THEN 
     CALL MCOPY (NM, 1, EXP_SOURCE, T_SOURCE) 
  ELSE 
     CALL MZERO (NM, 1, T_SOURCE) 
  ENDIF

  RETURN 
END SUBROUTINE DOUBLING_INTEGRATION


SUBROUTINE COMBINE_LAYERS (N, REFLECT1, TRANS1, SOURCE1, REFLECT2,&
     TRANS2, SOURCE2, OUT_REFLECT, OUT_TRANS, OUT_SOURCE)              
  !        COMBINE_LAYERS combines the reflection and transmission matrice
  !      and source vectors for two layers into a combined reflection,    
  !      transmission and source.  The positive side (down) of the first  
  !      layer is attached to the negative side (up) of the second layer; 
  !      thus layer 1 is put on top of layer 2.     
  use kinds
  IMPLICIT NONE
  INTEGER N 
  REAL(kind=dbl) REFLECT1 (N, N, 2), TRANS1 (N, N, 2) 
  REAL(kind=dbl) REFLECT2 (N, N, 2), TRANS2 (N, N, 2) 
  REAL(kind=dbl) SOURCE1 (N, 2), SOURCE2 (N, 2) 
  REAL(kind=dbl) OUT_REFLECT (N, N, 2), OUT_TRANS (N, N, 2) 
  REAL(kind=dbl) OUT_SOURCE (N, 2) 
  REAL(kind=dbl) Y_NN(N,N), X_NN(N,N), G_NN(N,N), ID_NN(N,N), WORK_N1(N), X_N2(N*N,1),  X_N3(N*N,1)
  INTEGER MAXM 
  PARAMETER (MAXM = 4096) 
  REAL(kind=dbl) X (MAXM), Y (MAXM) 
  REAL(kind=dbl) GAMMA (MAXM) 
  COMMON / SCRATCH1 / X, Y
  COMMON / SCRATCH2 / GAMMA

  !           GAMMAp = inv[1 - R1p * R2m]     (p for +,  m for -)         
!  CALL MMULT (N, N, N, REFLECT1 (1, 1, 1), REFLECT2 (1, 1, 2),      &
!       X)
  X_NN=MATMUL(REFLECT1 (:, :, 1), REFLECT2 (:, :, 2))
!  CALL MIDENTITY (N, Y)
  CALL MIDENTITY (N, ID_NN)
!  CALL MSUB (N, N, Y, X, Y)
  Y_NN=ID_NN - X_NN
!  CALL MINVERT (N, Y, GAMMA)
  CALL MINVERT (N, Y_NN, G_NN)

  !           RTp = R2p + T2p * GAMMAp * R1p * T2m                        
!  CALL MMULT (N, N, N, REFLECT1 (1, 1, 1), TRANS2 (1, 1, 2),        &
!       X)
  X_NN=MATMUL(REFLECT1 (:, :, 1), TRANS2 (:, :, 2))
!  CALL MMULT (N, N, N, GAMMA, X, Y)
  Y_NN=MATMUL(G_NN, X_NN)
!  CALL MMULT (N, N, N, TRANS2 (1, 1, 1), Y, X)
  X_NN=MATMUL(TRANS2 (:, :, 1), Y_NN)
!  CALL MADD (N, N, REFLECT2 (1, 1, 1), X, OUT_REFLECT (1, 1, 1) )
  OUT_REFLECT(:, :, 1)=REFLECT2 (:, :, 1) + X_NN

  !           TTp = T2p * GAMMAp * T1p
!  CALL MMULT (N, N, N, GAMMA, TRANS1 (1, 1, 1), X)
  X_NN=MATMUL(G_NN, TRANS1(:, :, 1))
!  CALL MMULT (N, N, N, TRANS2 (1, 1, 1), X, OUT_TRANS (1, 1, 1) )
  OUT_TRANS (:, :, 1) = MATMUL(TRANS2 (:, :, 1), X_NN)

  !           STp = S2p + T2p * GAMMAp * (S1p + R1p * S2m)
!  CALL MMULT (N, N, 1, REFLECT1 (1, 1, 1), SOURCE2 (1, 2), X)
  WORK_N1=MATMUL(REFLECT1 (:, :, 1), SOURCE2 (:, 2))
!  CALL MADD (N, 1, SOURCE1 (1, 1), X, Y)
  WORK_N1=SOURCE1(:,1)+ WORK_N1
!  CALL MMULT (N, N, 1, GAMMA, Y, X)
  WORK_N1=MATMUL(G_NN,WORK_N1)
!  CALL MMULT (N, N, 1, TRANS2 (1, 1, 1), X, Y)
  WORK_N1=MATMUL(TRANS2 (:, :, 1), WORK_N1)
!  CALL MADD (N, 1, SOURCE2 (1, 1), Y, OUT_SOURCE (1, 1) )
  OUT_SOURCE (:, 1)=SOURCE2 (:, 1) + WORK_N1

  !           GAMMAm = inv[1 - R2m * R1p]                                 
!  CALL MMULT (N, N, N, REFLECT2 (1, 1, 2), REFLECT1 (1, 1, 1),      &
!       X)
  X_NN=MATMUL(REFLECT2 (:, :, 2), REFLECT1 (:, :, 1))
!  CALL MIDENTITY (N, Y)
!  CALL MSUB (N, N, Y, X, Y)
  Y_NN= ID_NN - X_NN
!  CALL MINVERT (N, Y, GAMMA)
  CALL MINVERT (N, Y_NN, G_NN)

  !           RTm = R1m + T1m * GAMMAm * R2m * T1p                        
!  CALL MMULT (N, N, N, REFLECT2 (1, 1, 2), TRANS1 (1, 1, 1),        &
!       X)
  X_NN=MATMUL(REFLECT2 (:, :, 2), TRANS1 (:, :, 1))
!  CALL MMULT (N, N, N, GAMMA, X, Y)
  Y_NN=MATMUL(G_NN, X_NN)
!  CALL MMULT (N, N, N, TRANS1 (1, 1, 2), Y, X)
  X_NN=MATMUL(TRANS1 (:, :, 2), Y_NN)
!  CALL MADD (N, N, REFLECT1 (1, 1, 2), X, OUT_REFLECT (1, 1, 2) )
  OUT_REFLECT (:, :, 2)=REFLECT1 (:, :, 2) + X_NN

  !           TTm = T1m * GAMMAm * T2m
!  CALL MMULT (N, N, N, GAMMA, TRANS2 (1, 1, 2), X)
  X_NN=MATMUL(G_NN, TRANS2 (:, :, 2))
!  CALL MMULT (N, N, N, TRANS1 (1, 1, 2), X, OUT_TRANS (1, 1, 2) )
  OUT_TRANS (:, :, 2)=MATMUL(TRANS1 (:, :, 2), X_NN)

  !           STm = S1m + T1m * GAMMAm * (S2m + R2m * S1p)                
!  CALL MMULT (N, N, 1, REFLECT2 (1, 1, 2), SOURCE1 (1, 1), X)
  WORK_N1=MATMUL(REFLECT2 (:, :, 2), SOURCE1 (:, 1))
!  CALL MADD (N, 1, SOURCE2 (1, 2), X, Y)
  WORK_N1=SOURCE2 (:, 2) + WORK_N1
!  CALL MMULT (N, N, 1, GAMMA, Y, X)
  WORK_N1=MATMUL(G_NN, WORK_N1)
!  CALL MMULT (N, N, 1, TRANS1 (1, 1, 2), X, Y)
  WORK_N1=MATMUL(TRANS1 (:, :, 2), WORK_N1)
!  CALL MADD (N, 1, SOURCE1 (1, 2), Y, OUT_SOURCE (1, 2) )
  OUT_SOURCE (:, 2)=SOURCE1 (:, 2) + WORK_N1

  RETURN 
END SUBROUTINE COMBINE_LAYERS
