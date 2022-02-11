module Solutions.Relations

import Data.HList
import Data.Vect

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
natEq (S k) (S j) = cong S <$> natEq k j
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
