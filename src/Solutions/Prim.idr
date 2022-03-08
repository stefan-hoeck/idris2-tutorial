module Solutions.Prim

import Data.Bits
import Data.List

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
