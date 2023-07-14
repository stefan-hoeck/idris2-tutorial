module Solutions.Eq

import Data.HList
import Data.Vect
import Decidable.Equality

%default total

data ColType = I64 | Str | Boolean | Float

Schema : Type
Schema = List ColType

IdrisType : ColType -> Type
IdrisType I64     = Int64
IdrisType Str     = String
IdrisType Boolean = Bool
IdrisType Float   = Double

Row : Schema -> Type
Row = HList . map IdrisType

record Table where
  constructor MkTable
  schema : Schema
  size   : Nat
  rows   : Vect size (Row schema)

data SameColType : (c1, c2 : ColType) -> Type where
  SameCT : SameColType c1 c1

--------------------------------------------------------------------------------
--          Equality as a Type
--------------------------------------------------------------------------------

-- 1

sctReflexive : SameColType c1 c1
sctReflexive = SameCT

-- 2

sctSymmetric : SameColType c1 c2 -> SameColType c2 c1
sctSymmetric SameCT = SameCT

-- 3

sctTransitive : SameColType c1 c2 -> SameColType c2 c3 -> SameColType c1 c3
sctTransitive SameCT SameCT = SameCT

-- 4

sctCong : (f : ColType -> a) -> SameColType c1 c2 -> f c1 = f c2
sctCong f SameCT = Refl

-- 5

natEq : (n1,n2 : Nat) -> Maybe (n1 = n2)
natEq 0     0     = Just Refl
natEq (S k) (S j) = (\x => cong S x) <$> natEq k j
natEq (S k) 0     = Nothing
natEq 0     (S _) = Nothing

-- 6

appRows : {ts1 : _} -> Row ts1 -> Row ts2 -> Row (ts1 ++ ts2)
appRows {ts1 = []}     Nil      y = y
appRows {ts1 = _ :: _} (h :: t) y = h :: appRows t y

zip : Table -> Table -> Maybe Table
zip (MkTable s1 m rs1) (MkTable s2 n rs2) = case natEq m n of
  Just Refl => Just $ MkTable _ _ (zipWith appRows rs1 rs2)
  Nothing   => Nothing

--------------------------------------------------------------------------------
--          Programs as Proofs
--------------------------------------------------------------------------------

-- 1

mapIdEither : (ea : Either e a) -> map Prelude.id ea = ea
mapIdEither (Left ve)  = Refl
mapIdEither (Right va) = Refl

-- 2

mapIdList : (as : List a) -> map Prelude.id as = as
mapIdList []        = Refl
mapIdList (x :: xs) = cong (x ::) $ mapIdList xs

-- 3

data BaseType = DNABase | RNABase

data Nucleobase : BaseType -> Type where
  Adenine  : Nucleobase b
  Cytosine : Nucleobase b
  Guanine  : Nucleobase b
  Thymine  : Nucleobase DNABase
  Uracile  : Nucleobase RNABase

NucleicAcid : BaseType -> Type
NucleicAcid = List . Nucleobase

complementBase : (b : BaseType) -> Nucleobase b -> Nucleobase b
complementBase DNABase Adenine  = Thymine
complementBase RNABase Adenine  = Uracile
complementBase _       Cytosine = Guanine
complementBase _       Guanine  = Cytosine
complementBase _       Thymine  = Adenine
complementBase _       Uracile  = Adenine

complement : (b : BaseType) -> NucleicAcid b -> NucleicAcid b
complement b = map (complementBase b)

complementBaseId :  (b  : BaseType)
                 -> (nb : Nucleobase b)
                 -> complementBase b (complementBase b nb) = nb
complementBaseId DNABase Adenine  = Refl
complementBaseId RNABase Adenine  = Refl
complementBaseId DNABase Cytosine = Refl
complementBaseId RNABase Cytosine = Refl
complementBaseId DNABase Guanine  = Refl
complementBaseId RNABase Guanine  = Refl
complementBaseId DNABase Thymine  = Refl
complementBaseId RNABase Uracile  = Refl

complementId :  (b  : BaseType)
             -> (na : NucleicAcid b)
             -> complement b (complement b na) = na
complementId b []        = Refl
complementId b (x :: xs) =
  cong2 (::) (complementBaseId b x) (complementId b xs)

-- 4

replaceVect : Fin n -> a -> Vect n a -> Vect n a
replaceVect FZ     v (x :: xs) = v :: xs
replaceVect (FS k) v (x :: xs) = x :: replaceVect k v xs

indexReplace :  (ix : Fin n)
             -> (v : a)
             -> (as : Vect n a)
             -> index ix (replaceVect ix v as) = v
indexReplace FZ     v (x :: xs) = Refl
indexReplace (FS k) v (x :: xs) = indexReplace k v xs

-- 5

insertVect : (ix : Fin (S n)) -> a -> Vect n a -> Vect (S n) a
insertVect FZ     v xs        = v :: xs
insertVect (FS k) v (x :: xs) = x :: insertVect k v xs

indexInsert :  (ix : Fin (S n))
             -> (v : a)
             -> (as : Vect n a)
             -> index ix (insertVect ix v as) = v
indexInsert FZ     v xs        = Refl
indexInsert (FS k) v (x :: xs) = indexInsert k v xs

--------------------------------------------------------------------------------
--          Into the Void
--------------------------------------------------------------------------------

-- 1

Uninhabited (Vect (S n) Void) where
  uninhabited (_ :: _) impossible

-- 2

Uninhabited a => Uninhabited (Vect (S n) a) where
  uninhabited = uninhabited . head

-- 3

notSym : Not (a = b) -> Not (b = a)
notSym f prf = f $ sym prf

-- 4

notTrans : a = b -> Not (b = c) -> Not (a = c)
notTrans ab f ac = f $ trans (sym ab) ac

-- 5

data Crud : (i : Type) -> (a : Type) -> Type where
  Create : (value : a) -> Crud i a
  Update : (id : i) -> (value : a) -> Crud i a
  Read   : (id : i) -> Crud i a
  Delete : (id : i) -> Crud i a

Uninhabited a => Uninhabited i => Uninhabited (Crud i a) where
  uninhabited (Create value)    = uninhabited value
  uninhabited (Update id value) = uninhabited value
  uninhabited (Read id)         = uninhabited id
  uninhabited (Delete id)       = uninhabited id

-- 6

namespace DecEq
  DecEq ColType where
    decEq I64 I64         = Yes Refl
    decEq I64 Str         = No $ \case Refl impossible
    decEq I64 Boolean     = No $ \case Refl impossible
    decEq I64 Float       = No $ \case Refl impossible

    decEq Str I64         = No $ \case Refl impossible
    decEq Str Str         = Yes Refl
    decEq Str Boolean     = No $ \case Refl impossible
    decEq Str Float       = No $ \case Refl impossible

    decEq Boolean I64     = No $ \case Refl impossible
    decEq Boolean Str     = No $ \case Refl impossible
    decEq Boolean Boolean = Yes Refl
    decEq Boolean Float   = No $ \case Refl impossible

    decEq Float I64       = No $ \case Refl impossible
    decEq Float Str       = No $ \case Refl impossible
    decEq Float Boolean   = No $ \case Refl impossible
    decEq Float Float     = Yes Refl

-- 7

ctNat : ColType -> Nat
ctNat I64     = 0
ctNat Str     = 1
ctNat Boolean = 2
ctNat Float   = 3

ctNatInjective : (c1,c2 : ColType) -> ctNat c1 = ctNat c2 -> c1 = c2
ctNatInjective I64     I64     Refl = Refl
ctNatInjective Str     Str     Refl = Refl
ctNatInjective Boolean Boolean Refl = Refl
ctNatInjective Float   Float   Refl = Refl

DecEq ColType where
  decEq c1 c2 = case decEq (ctNat c1) (ctNat c2) of
    Yes prf    => Yes $ ctNatInjective c1 c2 prf
    No  contra => No $ \x => contra $ cong ctNat x

--------------------------------------------------------------------------------
--          Rewrite Rules
--------------------------------------------------------------------------------

-- 1

psuccRightSucc : (m,n : Nat) -> S (m + n) = m + S n
psuccRightSucc 0     n = Refl
psuccRightSucc (S k) n = cong S $ psuccRightSucc k n

-- 2

minusSelfZero : (n : Nat) -> minus n n = 0
minusSelfZero 0     = Refl
minusSelfZero (S k) = minusSelfZero k

-- 3

minusZero : (n : Nat) -> minus n 0 = n
minusZero 0     = Refl
minusZero (S k) = Refl

-- 4

timesOneLeft : (n : Nat) -> 1 * n = n
timesOneLeft 0     = Refl
timesOneLeft (S k) = cong S $ timesOneLeft k

timesOneRight : (n : Nat) -> n * 1 = n
timesOneRight 0     = Refl
timesOneRight (S k) = cong S $ timesOneRight k


-- 5

plusCommutes : (m,n : Nat) -> m + n = n + m
plusCommutes 0     n = rewrite plusZeroRightNeutral n in Refl
plusCommutes (S k) n =
  rewrite sym (psuccRightSucc n k)
  in cong S (plusCommutes k n)

-- 6

mapOnto : (a -> b) -> Vect k b -> Vect m a -> Vect (k + m) b
mapOnto            _ xs []        =
  rewrite plusZeroRightNeutral k in reverse xs
mapOnto {m = S m'} f xs (y :: ys) =
  rewrite sym (plusSuccRightSucc k m') in mapOnto f (f y :: xs) ys

mapTR : (a -> b) -> Vect n a -> Vect n b
mapTR f = mapOnto f Nil

-- 7

mapAppend :  (f : a -> b)
          -> (xs : List a)
          -> (ys : List a)
          -> map f (xs ++ ys) = map f xs ++ map f ys
mapAppend f []        ys = Refl
mapAppend f (x :: xs) ys = cong (f x ::) $ mapAppend f xs ys

-- 8

zip2 : Table -> Table -> Maybe Table
zip2 (MkTable s1 m rs1) (MkTable s2 n rs2) = case decEq m n of
  Yes Refl =>
    let rs2 = zipWith (++) rs1 rs2
     in Just $ MkTable (s1 ++ s2) _ (rewrite mapAppend IdrisType s1 s2 in rs2)
  No  _    => Nothing
