module Solutions.Predicates

import Decidable.Equality

%default total

--------------------------------------------------------------------------------
--          Preconditions
--------------------------------------------------------------------------------

data NonEmpty : (as : List a) -> Type where
  IsNonEmpty : NonEmpty (h :: t)

-- 1

tail : (as : List a) -> {auto 0 _ : NonEmpty as} -> List a
tail (_ :: xs) = xs
tail [] impossible

-- 2

concat1 : Semigroup a => (as : List a) -> {auto 0 _ : NonEmpty as} -> a
concat1 (h :: t) = foldl (<+>) h t

foldMap1 :  Semigroup m
         => (a -> m)
         -> (as : List a)
         -> {auto 0 _ : NonEmpty as}
         -> m
foldMap1 f (h :: t) = foldl (\x,y => x <+> f y) (f h) t

-- 3

maximum : Ord a => (as : List a) -> {auto 0 _ : NonEmpty as} -> a
maximum (x :: xs) = foldl max x xs

minimum : Ord a => (as : List a) -> {auto 0 _ : NonEmpty as} -> a
minimum (x :: xs) = foldl min x xs

-- 4

data Positive : Nat -> Type where
  IsPositive : Positive (S n)

saveDiv : (m,n : Nat) -> {auto 0 _ : Positive n} -> Nat
saveDiv m (S k) = go 0 m k
  where go : (res, rem, sub : Nat) -> Nat
        go res 0       _     = res
        go res (S rem) 0     = go (res + 1) rem k
        go res (S rem) (S x) = go res rem x

-- 5

data IsJust : Maybe a -> Type where
  ItIsJust : IsJust (Just v)

Uninhabited (IsJust Nothing) where
  uninhabited ItIsJust impossible

isJust : (m : Maybe a) -> Dec (IsJust m)
isJust Nothing  = No uninhabited
isJust (Just x) = Yes ItIsJust

-- 6

data IsLeft : Either e a -> Type where
  ItIsLeft : IsLeft (Left v)

Uninhabited (IsLeft $ Right w) where
  uninhabited ItIsLeft impossible

isLeft : (v : Either e a) -> Dec (IsLeft v)
isLeft (Right _) = No uninhabited
isLeft (Left x)  = Yes ItIsLeft

data IsRight : Either e a -> Type where
  ItIsRight : IsRight (Right v)

Uninhabited (IsRight $ Left w) where
  uninhabited ItIsRight impossible

isRight : (v : Either e a) -> Dec (IsRight v)
isRight (Left _)  = No uninhabited
isRight (Right x) = Yes ItIsRight

--------------------------------------------------------------------------------
--          Contracts between Values
--------------------------------------------------------------------------------

data ColType = I64 | Str | Boolean | Float

IdrisType : ColType -> Type
IdrisType I64     = Int64
IdrisType Str     = String
IdrisType Boolean = Bool
IdrisType Float   = Double

record Column where
  constructor MkColumn
  name : String
  type : ColType

infixr 8 :>

(:>) : String -> ColType -> Column
(:>) = MkColumn

Schema : Type
Schema = List Column

data Row : Schema -> Type where
  Nil  : Row []
  (::) :  {0 name : String}
       -> {0 type : ColType}
       -> (v : IdrisType type)
       -> Row ss
       -> Row (name :> type :: ss)

-- 1

data InSchema : (name : String) -> (ss : Schema) -> Type where
  IsHere  : (t : ColType) -> InSchema n (n :> t :: ss)
  IsThere : InSchema n ss -> InSchema n (fld :: ss)

Uninhabited (InSchema n []) where
  uninhabited (IsHere _) impossible
  uninhabited (IsThere _) impossible

0 ColumnType : InSchema n ss -> Type
ColumnType (IsHere t)  = IdrisType t
ColumnType (IsThere x) = ColumnType x

getAt :  {0 ss   : Schema}
      -> (name : String)
      -> Row ss
      -> {auto prf : InSchema name ss}
      -> ColumnType prf
getAt name (v :: vs) {prf = IsHere t}  = v
getAt name (_ :: vs) {prf = IsThere p} = getAt name vs

inSchema' : (ss : Schema) -> (n : String) -> Maybe (InSchema n ss)
inSchema' []                    _ = Nothing
inSchema' (MkColumn cn t :: xs) n = case decEq cn n of
  Yes Refl   => Just $ IsHere t
  No  contra => case inSchema' xs n of
    Just prf => Just $ IsThere prf
    Nothing  => Nothing

-- 2

inSchema : (ss : Schema) -> (n : String) -> Dec (InSchema n ss)
inSchema []                    _ = No uninhabited
inSchema (MkColumn cn t :: xs) n = case decEq cn n of
  Yes Refl   => Yes $ IsHere t
  No  contra => case inSchema xs n of
    Yes prf     => Yes $ IsThere prf
    No  contra2 => No $ \case IsHere _  => contra Refl
                              IsThere p => contra2 p

-- 3

updateAt : (name : String)
         -> Row ss
         -> {auto prf : InSchema name ss}
         -> (f : ColumnType prf -> ColumnType prf)
         -> Row ss
updateAt name (v :: vs) {prf = IsHere _}  f = f v :: vs
updateAt name (v :: vs) {prf = IsThere p} f = v :: updateAt name vs f

-- 4

public export
data Elems : (xs,ys : List a) -> Type where
  ENil   : Elems [] ys
  EHere  : Elems xs ys -> Elems (x :: xs) (x :: ys)
  EThere : Elems xs ys -> Elems xs (y :: ys)

-- 5

extract :  (0 s1 : Schema)
        -> (row : Row s2)
        -> {auto prf : Elems s1 s2}
        -> Row s1
extract []       _         {prf = ENil}     = []
extract (_ :: t) (v :: vs) {prf = EHere x}  = v :: extract t vs
extract s1       (v :: vs) {prf = EThere x} = extract s1 vs

-- 6

namespace AllInSchema
  public export
  data AllInSchema : List String -> Schema -> Type where
    Nil  : AllInSchema [] s
    (::) : InSchema n s -> AllInSchema ns s -> AllInSchema (n :: ns) s

0 ColumnAt : {ss : Schema} -> InSchema n ss -> Column
ColumnAt {ss = n :> t :: _} (IsHere t)  = n :> t
ColumnAt {ss = _      :: _} (IsThere x) = ColumnAt x

0 Columns : {ss : Schema} -> AllInSchema names ss -> Schema
Columns []            = []
Columns (prf :: prfs) = ColumnAt prf :: Columns prfs

-- getAll :  {0 ss  : Schema}
--        -> (names : List String)
--        -> Row ss
--        -> {auto prf : AllInSchema names ss}
--        -> Row (Columns prf)
-- getAll []        row {prf = []}      = []
-- getAll (n :: ns) (v :: _)  {prf = IsHere t  :: ps} = ?foo_2
-- getAll (n :: ns) (v :: vs) {prf = IsThere x :: ps} = ?foo_1




--------------------------------------------------------------------------------
--          Tests
--------------------------------------------------------------------------------

EmployeeSchema : Schema
EmployeeSchema = [ "firstName"  :> Str
                 , "lastName"   :> Str
                 , "email"      :> Str
                 , "age"        :> I64
                 , "salary"     :> Float
                 , "management" :> Boolean
                 ]

0 Employee : Type
Employee = Row EmployeeSchema

hock : Employee
hock = [ "Stefan", "Höck", "hock@foo.com", 46, 5443.2, False ]

shoeck : String
shoeck = getAt "firstName" hock ++ " " ++ getAt "lastName" hock
