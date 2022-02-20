module Solutions.Predicates

import Decidable.Equality

%default total

--------------------------------------------------------------------------------
--          Preconditions
--------------------------------------------------------------------------------

data NonEmpty : (as : List a) -> Type where
  IsNonEmpty : NonEmpty (h :: t)

-- 1

tail : (as : List a) -> (0 _ : NonEmpty as) => List a
tail (_ :: xs) = xs
tail [] impossible

-- 2

concat1 : Semigroup a => (as : List a) -> (0 _ : NonEmpty as) => a
concat1 (h :: t) = foldl (<+>) h t

foldMap1 : Semigroup m => (a -> m) -> (as : List a) -> (0 _ : NonEmpty as) => m
foldMap1 f (h :: t) = foldl (\x,y => x <+> f y) (f h) t

-- 3

maximum : Ord a => (as : List a) -> (0 _ : NonEmpty as) => a
maximum (x :: xs) = foldl max x xs

minimum : Ord a => (as : List a) -> (0 _ : NonEmpty as) => a
minimum (x :: xs) = foldl min x xs

-- 4

data Positive : Nat -> Type where
  IsPositive : Positive (S n)

saveDiv : (m,n : Nat) -> (0 _ : Positive n) => Nat
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

data InSchema :  (name    : String)
              -> (schema  : Schema)
              -> (colType : ColType)
              -> Type where
  [search name schema]
  IsHere  : InSchema n (n :> t :: ss) t
  IsThere : InSchema n ss t -> InSchema n (fld :: ss) t

getAt :  {0 ss   : Schema}
      -> (name : String)
      -> Row ss
      -> (prf : InSchema name ss c)
      => IdrisType c
getAt name (v :: vs) {prf = IsHere}    = v
getAt name (_ :: vs) {prf = IsThere p} = getAt name vs

-- 1

Uninhabited (InSchema n [] c) where
  uninhabited IsHere impossible
  uninhabited (IsThere _) impossible

inSchema : (ss : Schema) -> (n : String) -> Dec (c ** InSchema n ss c)
inSchema []                    _ = No $ \(_ ** prf) => uninhabited prf
inSchema (MkColumn cn t :: xs) n = case decEq cn n of
  Yes Refl   => Yes (t ** IsHere)
  No  contra => case inSchema xs n of
    Yes (t ** prf) => Yes (t ** IsThere prf)
    No  contra2    => No $ \case (_ ** IsHere)    => contra Refl
                                 (t ** IsThere p) => contra2 (t ** p)

-- 2

updateAt : (name : String)
         -> Row ss
         -> (prf : InSchema name ss c)
         => (f : IdrisType c -> IdrisType c)
         -> Row ss
updateAt name (v :: vs) {prf = IsHere}    f = f v :: vs
updateAt name (v :: vs) {prf = IsThere p} f = v :: updateAt name vs f

-- 3

public export
data Elems : (xs,ys : List a) -> Type where
  ENil   : Elems [] ys
  EHere  : Elems xs ys -> Elems (x :: xs) (x :: ys)
  EThere : Elems xs ys -> Elems xs (y :: ys)

extract :  (0 s1 : Schema)
        -> (row : Row s2)
        -> (prf : Elems s1 s2)
        => Row s1
extract []       _         {prf = ENil}     = []
extract (_ :: t) (v :: vs) {prf = EHere x}  = v :: extract t vs
extract s1       (v :: vs) {prf = EThere x} = extract s1 vs

-- 4

namespace AllInSchema
  public export
  data AllInSchema :  (names : List String)
                   -> (schema : Schema)
                   -> (result : Schema)
                   -> Type where
    [search names schema]
    Nil  :  AllInSchema [] s []
    (::) :  InSchema n s c
         -> AllInSchema ns s res
         -> AllInSchema (n :: ns) s (n :> c :: res)

getAll :  {0 ss  : Schema}
       -> (names : List String)
       -> Row ss
       -> (prf : AllInSchema names ss res)
       => Row res
getAll []        _   {prf = []}     = []
getAll (n :: ns) row {prf = _ :: _} = getAt n row :: getAll ns row

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

shoeck2 : String
shoeck2 = case getAll ["firstName", "lastName", "age"] hock of
  [fn,ln,a] => "\{fn} \{ln}: \{show a} years old."
