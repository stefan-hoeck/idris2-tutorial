module Solutions.Prim

import Data.Bits
import Data.List
import Data.Maybe
import Data.SnocList
import Decidable.Equality

%default total

--------------------------------------------------------------------------------
--          Working with Strings
--------------------------------------------------------------------------------

-- 1

map : (Char -> Char) -> String -> String
map f = pack . map f . unpack

filter : (Char -> Bool) -> String -> String
filter f = pack . filter f . unpack

mapMaybe : (Char -> Maybe Char) -> String -> String
mapMaybe f = pack . mapMaybe f . unpack

-- 2

foldl : (a -> Char -> a) -> a -> String -> a
foldl f v = foldl f v . unpack

foldMap : Monoid m => (Char -> m) -> String -> m
foldMap f = foldMap f . unpack

-- 3

traverse : Applicative f => (Char -> f Char) -> String -> f String
traverse fun = map pack . traverse fun . unpack

-- 4
(>>=) : String -> (Char -> String) -> String
str >>= f = foldMap f $ unpack str

--------------------------------------------------------------------------------
--          Integers
--------------------------------------------------------------------------------

-- 1

record And a where
  constructor MkAnd
  value : a

Bits a => Semigroup (And a) where
  MkAnd x <+> MkAnd y = MkAnd $ x .&. y

Bits a => Monoid (And a) where
  neutral = MkAnd oneBits

-- 2

record Or a where
  constructor MkOr
  value : a

Bits a => Semigroup (Or a) where
  MkOr x <+> MkOr y = MkOr $ x .|. y

Bits a => Monoid (Or a) where
  neutral = MkOr zeroBits

-- 3

even : Bits64 -> Bool
even x = not $ testBit x 0

-- 4

binChar : Bits64 -> Char
binChar x = if testBit x 0 then '1' else '0'

toBin : Bits64 -> String
toBin 0 = "0"
toBin v = go [] v
  where go : List Char -> Bits64 -> String
        go cs 0 = pack cs
        go cs v = go (binChar v :: cs) (assert_smaller v $ v `shiftR` 1)

-- 5

-- Note: We know that `x .&. 15` must be a value in the range
-- [0,15] (unless there is a bug in the backend we use), but since
-- `Bits64` is a primitive, Idris can't know this. We therefore
-- fail with a runtime crash in the impossible case, but annotate the
-- call to `idris_crash` with `assert_total` (otherwise, `hexChar` would
-- be a partial function).
hexChar : Bits64 -> Char
hexChar x = case x .&. 15 of
  0  => '0'
  1  => '1'
  2  => '2'
  3  => '3'
  4  => '4'
  5  => '5'
  6  => '6'
  7  => '7'
  8  => '8'
  9  => '9'
  10 => 'a'
  11 => 'b'
  12 => 'c'
  13 => 'd'
  14 => 'e'
  15 => 'f'
  x  => assert_total $ idris_crash "IMPOSSIBLE: Invalid hex digit (\{show x})"

toHex : Bits64 -> String
toHex 0 = "0"
toHex v = go [] v
  where go : List Char -> Bits64 -> String
        go cs 0 = pack cs
        go cs v = go (hexChar v :: cs) (assert_smaller v $ v `shiftR` 4)

--------------------------------------------------------------------------------
--          Refined Primitives
--------------------------------------------------------------------------------

data Dec0 : (prop : Type) -> Type where
  Yes0 : (0 prf : prop) -> Dec0 prop
  No0  : (0 contra : prop -> Void) -> Dec0 prop

interface Decidable (0 a : Type) (0 p : a -> Type) | p where
  decide : (v : a) -> Dec0 (p v)

decideOn : (0 p : a -> Type) -> Decidable a p => (v : a) -> Dec0 (p v)
decideOn _ = decide

test0 : (b : Bool) -> Dec0 (b === True)
test0 True  = Yes0 Refl
test0 False = No0 absurd

-- 1

{x : a} -> DecEq a => Decidable a (Equal x) where
  decide v = case decEq x v of
    Yes prf   => Yes0 prf
    No contra => No0 contra

-- 2

data Neg : (p : a -> Type) -> a -> Type where
  IsNot : {0 p : a -> Type} -> (contra : p v -> Void) -> Neg p v

Decidable a p => Decidable a (Neg p) where
  decide v = case decideOn p v of
    Yes0 prf   => No0 $ \(IsNot contra) => contra prf
    No0 contra => Yes0 $ IsNot contra

-- 3

data (&&) : (p,q : a -> Type) -> a -> Type where
  Both : {0 p,q : a -> Type} -> (prf1 : p v) -> (prf2 : q v) -> (&&) p q v

Decidable a p => Decidable a q => Decidable a (p && q) where
  decide v = case decideOn p v of
    Yes0 prf1 => case decideOn q v of
      Yes0 prf2   => Yes0 $ Both prf1 prf2
      No0  contra => No0 $ \(Both _ prf2) => contra prf2
    No0  contra => No0 $ \(Both prf1 _) => contra prf1

-- 4

data (||) : (p,q : a -> Type) -> a -> Type where
  L : {0 p,q : a -> Type} -> (prf : p v) -> (p || q) v
  R : {0 p,q : a -> Type} -> (prf : q v) -> (p || q) v

Decidable a p => Decidable a q => Decidable a (p || q) where
  decide v = case decideOn p v of
    Yes0 prf1    => Yes0 $ L prf1
    No0  contra1 => case decideOn q v of
      Yes0 prf2    => Yes0 $ R prf2
      No0  contra2 => No0 $ \case L prf => contra1 prf
                                  R prf => contra2 prf

-- 5

negOr : Neg (p || q) v -> (Neg p && Neg q) v
negOr (IsNot contra) = Both (IsNot $ contra . L) (IsNot $ contra . R)

andNeg : (Neg p && Neg q) v -> Neg (p || q) v
andNeg (Both (IsNot c1) (IsNot c2)) =
  IsNot $ \case L p1 => c1 p1
                R p2 => c2 p2

orNeg : (Neg p || Neg q) v -> Neg (p && q) v
orNeg (L (IsNot contra)) = IsNot $ \(Both p1 _) => contra p1
orNeg (R (IsNot contra)) = IsNot $ \(Both _ p2) => contra p2

0 negAnd :  Decidable a p
         => Decidable a q
         => Neg (p && q) v
         -> (Neg p || Neg q) v
negAnd (IsNot contra) = case decideOn p v of
  Yes0 p1 => case decideOn q v of
    Yes0 p2 => void (contra $ Both p1 p2)
    No0 c   => R $ IsNot c
  No0 c    => L $ IsNot c

-- 6

data (<=) : (m,n : Nat) -> Type where
  ZLTE : 0 <= n
  SLTE : m <= n -> S m <= S n

(>=) : (m,n : Nat) -> Type
m >= n = n <= m

(<) : (m,n : Nat) -> Type
m < n = S m <= n

(>) : (m,n : Nat) -> Type
m > n = n < m

Uninhabited (S n <= 0) where
  uninhabited ZLTE impossible
  uninhabited (SLTE _) impossible

0 fromLTE : (n1,n2 : Nat) -> (n1 <= n2) === True -> n1 <= n2
fromLTE 0     n2    prf = ZLTE
fromLTE (S k) (S j) prf = SLTE $ fromLTE k j prf
fromLTE (S k) 0     prf = absurd prf

0 toLTE : (n1,n2 : Nat) -> n1 <= n2 -> (n1 <= n2) === True
toLTE 0     0     _        = Refl
toLTE 0     (S k) _        = Refl
toLTE (S k) (S j) (SLTE x) = toLTE k j x
toLTE (S k) 0     x        = absurd x

{n : Nat} -> Decidable Nat (<= n) where
  decide m = case test0 (m <= n) of
    Yes0 prf   => Yes0 $ fromLTE m n prf
    No0 contra => No0 $ contra . toLTE m n

0 reflexive : {n : Nat} -> n <= n
reflexive {n = 0}   = ZLTE
reflexive {n = S _} = SLTE reflexive

0 transitive : {l,m,n : Nat} -> l <= m -> m <= n -> l <= n
transitive {l = 0}   _        _        = ZLTE
transitive {l = S _} (SLTE x) (SLTE y) = SLTE $ transitive x y

-- 9

record Percentage where
  constructor MkPercentage
  value : Bits8
  0 prf : cast value <= 100

percentage : Bits8 -> Maybe Percentage
percentage v = case decideOn (<= 100) (cast v) of
  Yes0 prf => Just $ MkPercentage v prf
  No0  _   => Nothing

namespace Percentage
  public export
  fromInteger :  (n : Integer)
              -> {auto 0 _ : IsJust (percentage (cast n))}
              -> Percentage
  fromInteger n = fromJust $ percentage (cast n)

-- 10

InRange : (m,n : Nat) -> Nat -> Type
InRange m n = (>= m) && (<= n)

record Something where
  constructor MkSomething
  value : Bits8
  0 prf : InRange 20 30 (cast value)

toPerc : Something -> Percentage
toPerc (MkSomething v (Both _ p)) = MkPercentage v (transitive p %search)

-- fst : (p && q) v -> p v
-- fst (Both prf1 prf2) = prf1
--
-- snd : (p && q) v -> q v
-- snd (Both prf1 prf2) = prf2

-- isAscii : Char -> Bool
-- isAscii c = ord c <= 127
--
-- data IsAscii : (v : Char) -> Type where
--   ItIsAscii : (0 prf : isAscii c === True) -> IsAscii c
--
-- Decidable IsAscii where
--   decide v = case test (isAscii v) of
--     Yes0 prf    => Yes0 $ ItIsAscii prf
--     No0  contra => No0 $ \(ItIsAscii prf) => contra prf
--
-- -- 5
--
-- data Head : (p : a -> Type) -> List a -> Type where
--   AtHead : {0 p : a -> Type} -> (0 prf : p v) -> Head p (v :: vs)
--
-- Uninhabited (Head p []) where
--   uninhabited (AtHead _) impossible
--
-- Decidable p => Decidable (Head p) where
--   decide []        = No0 $ \prf => absurd prf
--   decide (x :: xs) = case decide {p} x of
--     Yes0 prf    => Yes0 $ AtHead prf
--     No0  contra => No0 $ \(AtHead prf) => contra prf
--
-- -- 6
--
-- data MaxLength : (n : Nat) -> List a -> Type where
--   IsMaxLength : (0 prf : LTE (length vs) n) -> MaxLength n vs
--
-- data MinLength : (n : Nat) -> List a -> Type where
--   IsMinLength : (0 prf : LTE n (length vs)) -> MinLength n vs
--
-- {n : Nat} -> Decidable (MaxLength n) where
--   decide vs = case test (length vs <= n) of
--     Yes0 prf   => Yes0 $ IsMaxLength (fromLessThan (length vs) n prf)
--     No0 contra => No0  $ \(IsMaxLength prf) =>
--       contra $ toLessThan (length vs) n prf
--
-- {n : Nat} -> Decidable (MinLength n) where
--   decide vs = case test (n <= length vs) of
--     Yes0 prf   => Yes0 $ IsMinLength (fromLessThan n (length vs) prf)
--     No0 contra => No0  $ \(IsMinLength prf) =>
--       contra $ toLessThan n (length vs) prf
--
-- -- 7
--
-- data IsAlpha : (v : Char) -> Type where
--   ItIsAlpha : (0 prf : isAlpha c === True) -> IsAlpha c
--
-- Decidable IsAlpha where
--   decide v = case test (isAlpha v) of
--     Yes0 prf    => Yes0 $ ItIsAlpha prf
--     No0  contra => No0 $ \(ItIsAlpha prf) => contra prf
--
-- isIdentChar : Char -> Bool
-- isIdentChar '_' = True
-- isIdentChar c   = isAlphaNum c
--
-- data IsIdentChar : (v : Char) -> Type where
--   ItIsIdentChar : (0 prf : isIdentChar c === True) -> IsIdentChar c
--
-- Decidable IsIdentChar where
--   decide v = case test (isIdentChar v) of
--     Yes0 prf    => Yes0 $ ItIsIdentChar prf
--     No0  contra => No0 $ \(ItIsIdentChar prf) => contra prf
--
-- -- 8
--
-- data All : (p : a -> Type) -> (as : List a) -> Type where
--   Nil  : All p []
--   (::) :  {0 p : a -> Type}
--        -> (0 h : p v)
--        -> (0 t : All p vs)
--        -> All p (v :: vs)
--
-- data AllSnoc : (p : a -> Type) -> (as : SnocList a) -> Type where
--   Lin  : AllSnoc p [<]
--   (:<) :  {0 p : a -> Type}
--        -> (0 i : AllSnoc p vs)
--        -> (0 l : p v)
--        -> AllSnoc p (vs :< v)
--
-- 0 head : All p (x :: xs) -> p x
-- head (h :: _) = h
--
-- 0 (<>>) : AllSnoc p sx -> All p xs -> All p (sx <>> xs)
-- (<>>) [<]      y = y
-- (<>>) (i :< l) y = i <>> l :: y
--
-- 0 suffix : (sx : SnocList a) -> All p (sx <>> xs) -> All p xs
-- suffix [<]       x = x
-- suffix (sx :< y) x = let (_ :: t) = suffix {xs = y :: xs} sx x in t
--
-- 0 notInner :  {0 p : a -> Type}
--            -> (sx : SnocList a)
--            -> (0 contra : (0 prf : p x) -> Void)
--            -> (0 prfs : All p (sx <>> x :: xs))
--            -> Void
-- notInner sx contra prfs = let prfs2 = suffix sx prfs in contra (head prfs2)
--
-- allTR : {0 p : a -> Type} -> Decidable p => (as : List a) -> Dec0 (All p as)
-- allTR as = go Lin as
--   where go : (0 sp : AllSnoc p sx) -> (xs : List a) -> Dec0 (All p (sx <>> xs))
--         go sp []        = Yes0 $ sp <>> Nil
--         go sp (x :: xs) = case decide {p} x of
--           Yes0 prf    => go (sp :< prf) xs
--           No0  contra => No0 $ \prf => notInner sx contra prf
--
-- Decidable p => Decidable (All p) where decide = allTR
--
-- -- 9
--
-- 0 IdentChars : List Char -> Type
-- IdentChars = MaxLength 100 && Head IsAlpha && All IsIdentChar
--
-- record Identifier where
--   constructor MkIdentifier
--   value : String
--   0 prf : IdentChars (unpack value)
--
-- identifier : String -> Maybe Identifier
-- identifier s = case decide {p = IdentChars} (unpack s) of
--   Yes0 prf => Just $ MkIdentifier s prf
--   No0  _   => Nothing
--
-- namespace Identifier
--   public export
--   fromString : (s : String) -> {auto 0 _ : IsJust (identifier s)} -> Identifier
--   fromString s = fromJust $ identifier s
--
-- test_Ident123 : Identifier
-- test_Ident123 = "test_Ident123"
--
-- -- 10
--
-- 0 mapAll :  {0 p,q : a -> Type}
--          -> (forall a . p a -> q a)
--          -> All p as
--          -> All q as
-- mapAll f []       = []
-- mapAll f (h :: t) = f h :: mapAll f t
--
-- 0 identCharToAscii : IsIdentChar c -> IsAscii c
-- identCharToAscii (ItIsIdentChar p) = ItIsAscii $ believe_me p
--
-- record Ascii where
--   constructor MkAscii
--   value : String
--   0 prf : All IsAscii (unpack value)
--
-- 0 toAsciiPrf : IdentChars cs -> All IsAscii cs
-- toAsciiPrf (Both _ (Both _ prf)) = mapAll identCharToAscii prf
--
-- identToAscii : Identifier -> Ascii
-- identToAscii (MkIdentifier value prf) = MkAscii value $ toAsciiPrf prf
--
-- main : IO ()
-- main = do
--   str <- getLine
--   case identifier str of
--     Just _  => putStrLn "This is a valid identifier: \{str}"
--     Nothing => putStrLn "This is not a valid identifier: \{str}"
