module Solutions.Interfaces

%default total

--------------------------------------------------------------------------------
--          Basics
--------------------------------------------------------------------------------

interface Comp a where
  comp : a -> a -> Ordering

-- 1
anyLarger : Comp a => a -> List a -> Bool
anyLarger va []        = False
anyLarger va (x :: xs) = comp va x == GT || anyLarger va xs

-- 2
allLarger : Comp a => a -> List a -> Bool
allLarger va []        = True
allLarger va (x :: xs) = comp va x == GT && allLarger va xs

-- 3
maxElem : Comp a => List a -> Maybe a
maxElem []        = Nothing
maxElem (x :: xs) = case maxElem xs of
  Nothing => Just x
  Just v  => if comp x v == GT then Just x else Just v

minElem : Comp a => List a -> Maybe a
minElem []        = Nothing
minElem (x :: xs) = case minElem xs of
  Nothing => Just x
  Just v  => if comp x v == LT then Just x else Just v

-- 4
interface Concat a where
  concat : a -> a -> a

implementation Concat String where
  concat = (++)

implementation Concat (List a) where
  concat = (++)

-- 5
concatList : Concat a => List a -> Maybe a
concatList []        = Nothing
concatList (x :: xs) = case concatList xs of
  Nothing => Just x
  Just v  => Just (concat x v)

--------------------------------------------------------------------------------
--          More about Interfaces
--------------------------------------------------------------------------------

-- 1
interface Equals a where
  eq : a -> a -> Bool

  neq : a -> a -> Bool
  neq x y = not (eq x y)

interface Concat a => Empty a where
  empty : a

Equals a => Equals b => Equals (a,b) where
  eq (x1,y1) (x2,y2) = eq x1 x2 && eq y1 y2

Comp a => Comp b => Comp (a,b) where
  comp (x1,y1) (x2,y2) = case comp x1 x2 of
    EQ => comp y1 y2
    v  => v

Concat a => Concat b => Concat (a,b) where
  concat (x1,y1) (x2,y2) = (concat x1 x2, concat y1 y2)

Empty a => Empty b => Empty (a,b) where
  empty = (empty, empty)

-- 2
data Tree : Type -> Type where
  Leaf : a -> Tree a
  Node : Tree a -> Tree a -> Tree a

Equals a => Equals (Tree a) where
  eq (Leaf x)     (Leaf y)     = eq x y
  eq (Node l1 r1) (Node l2 r2) = eq l1 l2 && eq r1 r2
  eq _            _            = False

Concat (Tree a) where
  concat = Node

--------------------------------------------------------------------------------
--          Interfaces in the Prelude
--------------------------------------------------------------------------------

-- 1
record Complex where
  constructor MkComplex
  rel : Double
  img : Double

Eq Complex where
  MkComplex r1 i1 == MkComplex r2 i2 = r1 == r2 && i1 == i2

Num Complex where
  MkComplex r1 i1 + MkComplex r2 i2 = MkComplex (r1 + r2) (i1 + i2)
  MkComplex r1 i1 * MkComplex r2 i2 =
    MkComplex (r1 * r2 - i1 * i2) (r1 * i2 + r2 * i1)
  fromInteger n = MkComplex (fromInteger n) 0.0

Neg Complex where
  negate (MkComplex r i) = MkComplex (negate r) (negate i)
  MkComplex r1 i1 - MkComplex r2 i2 = MkComplex (r1 - r2) (i1 - i2)

Fractional Complex where
  MkComplex r1 i1 / MkComplex r2 i2 = case r2 * r2 + i2 * i2 of
    denom => MkComplex ((r1 * r2 + i1 * i2) / denom)
                       ((i1 * r2 - r1 * i2) / denom)

-- 2
Show Complex where
  showPrec p c = showCon p "MkComplex" (showArg c.rel ++ showArg c.img)

-- 3
record First a where
  constructor MkFirst
  value : Maybe a

pureFirst : a -> First a
pureFirst = MkFirst . Just

mapFirst : (a -> b) -> First a -> First b
mapFirst f = MkFirst . map f . value

mapFirst2 : (a -> b -> c) -> First a -> First b -> First c
mapFirst2 f (MkFirst (Just va)) (MkFirst (Just vb)) = pureFirst (f va vb)
mapFirst2 _ _ _ = MkFirst Nothing

Eq a => Eq (First a) where
  (==) = (==) `on` value

Ord a => Ord (First a) where
  compare = compare `on` value

Show a => Show (First a) where
  show = show . value

FromString a => FromString (First a) where
  fromString = pureFirst . fromString

FromDouble a => FromDouble (First a) where
  fromDouble = pureFirst . fromDouble

FromChar a => FromChar (First a) where
  fromChar = pureFirst . fromChar

Num a => Num (First a) where
  (+) = mapFirst2 (+)
  (*) = mapFirst2 (*)
  fromInteger = pureFirst . fromInteger

Neg a => Neg (First a) where
  negate = mapFirst negate
  (-) = mapFirst2 (-)

Integral a => Integral (First a) where
  mod = mapFirst2 mod
  div = mapFirst2 div

Fractional a => Fractional (First a) where
  (/) = mapFirst2 (/)
  recip = mapFirst recip

-- 4
Semigroup (First a) where
  l@(MkFirst (Just _)) <+> _ = l
  _                    <+> r = r

Monoid (First a) where
  neutral = MkFirst Nothing

-- 5
record Last a where
  constructor MkLast
  value : Maybe a

pureLast : a -> Last a
pureLast = MkLast . Just

mapLast : (a -> b) -> Last a -> Last b
mapLast f = MkLast . map f . value

mapLast2 : (a -> b -> c) -> Last a -> Last b -> Last c
mapLast2 f (MkLast (Just va)) (MkLast (Just vb)) = pureLast (f va vb)
mapLast2 _ _ _ = MkLast Nothing

Eq a => Eq (Last a) where
  (==) = (==) `on` value

Ord a => Ord (Last a) where
  compare = compare `on` value

Show a => Show (Last a) where
  show = show . value

FromString a => FromString (Last a) where
  fromString = pureLast . fromString

FromDouble a => FromDouble (Last a) where
  fromDouble = pureLast . fromDouble

FromChar a => FromChar (Last a) where
  fromChar = pureLast . fromChar

Num a => Num (Last a) where
  (+) = mapLast2 (+)
  (*) = mapLast2 (*)
  fromInteger = pureLast . fromInteger

Neg a => Neg (Last a) where
  negate = mapLast negate
  (-) = mapLast2 (-)

Integral a => Integral (Last a) where
  mod = mapLast2 mod
  div = mapLast2 div

Fractional a => Fractional (Last a) where
  (/) = mapLast2 (/)
  recip = mapLast recip

Semigroup (Last a) where
  _ <+> r@(MkLast (Just _)) = r
  l <+> _                   = l

Monoid (Last a) where
  neutral = MkLast Nothing

-- 6
last : List a -> Maybe a
last = value . foldMap pureLast

-- 7
record Any where
  constructor MkAny
  any : Bool

Semigroup Any where
  MkAny x <+> MkAny y = MkAny (x || y)

Monoid Any where
  neutral = MkAny False

record All where
  constructor MkAll
  all : Bool

Semigroup All where
  MkAll x <+> MkAll y = MkAll (x && y)

Monoid All where
  neutral = MkAll True

-- 8
anyElem : (a -> Bool) -> List a -> Bool
anyElem f = any . foldMap (MkAny . f)

allElems : (a -> Bool) -> List a -> Bool
allElems f = all . foldMap (MkAll . f)

-- 9
record Sum a where
  constructor MkSum
  value : a

record Product a where
  constructor MkProduct
  value : a

Num a => Semigroup (Sum a) where
  MkSum x <+> MkSum y = MkSum (x + y)

Num a => Monoid (Sum a) where
  neutral = MkSum 0

Num a => Semigroup (Product a) where
  MkProduct x <+> MkProduct y = MkProduct (x * y)

Num a => Monoid (Product a) where
  neutral = MkProduct 1

-- 10

sumList : Num a => List a -> a
sumList = value . foldMap MkSum

productList : Num a => List a -> a
productList = value . foldMap MkProduct

-- 12

data Element = H | C | N | O | F

record Mass where
  constructor MkMass
  value : Double

FromDouble Mass
  where fromDouble = MkMass

Eq Mass where
  (==) = (==) `on` value

Ord Mass where
  compare = compare `on` value

Show Mass where
  show = show . value

Semigroup Mass where
  x <+> y = MkMass $ x.value + y.value

Monoid Mass where
  neutral = 0.0

-- 13

atomicMass : Element -> Mass
atomicMass H = 1.008
atomicMass C = 12.011
atomicMass N = 14.007
atomicMass O = 15.999
atomicMass F = 18.9984

formulaMass : List (Element,Nat) -> Mass
formulaMass = foldMap pairMass
  where pairMass : (Element,Nat) -> Mass
        pairMass (e, n) = MkMass $ value (atomicMass e) * cast n
