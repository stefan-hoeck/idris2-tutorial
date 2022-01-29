||| This was first introduced in chapter *Functor and Friends*
||| and is used in later chapters as well.
module Text.CSV

import Data.HList
import Data.List1
import Data.Maybe
import Data.String
import Data.Validated

%default total

--------------------------------------------------------------------------------
--          CSVField
--------------------------------------------------------------------------------

public export
interface CSVField a where
  read : String -> Maybe a

--------------------------------------------------------------------------------
--          Implementations
--------------------------------------------------------------------------------

public export
CSVField Bool where
  read "t" = Just True
  read "f" = Just False
  read _   = Nothing

public export
CSVField Nat where
  read = parsePositive

public export
CSVField Integer where
  read = parseInteger

public export
CSVField Double where
  read = parseDouble

public export
CSVField String where
  read = Just

boundedPos : Cast Nat a => (max : Nat) -> String -> Maybe a
boundedPos max str =
  parsePositive str >>= \v => toMaybe (v <= max) (cast v)

public export
CSVField Bits8 where
  read = boundedPos 0xff

public export
CSVField Bits16 where
  read = boundedPos 0xffff

public export
CSVField Bits32 where
  read = boundedPos 0xffffffff

public export
CSVField Bits64 where
  read = boundedPos 0xffffffffffffffff

boundedInt : Cast Integer a => (min,max : Integer) -> String -> Maybe a
boundedInt min max str =
  parseInteger str >>= \v => toMaybe (min <= v && v <= max) (cast v)

public export
CSVField Int8 where
  read = boundedInt (-0x80) 0x7f

public export
CSVField Int16 where
  read = boundedInt (-0x8000) 0x7fff

public export
CSVField Int32 where
  read = boundedInt (-0x80000000) 0x7fffffff

public export
CSVField Int64 where
  read = boundedInt (-0x8000000000000000) 0x7fffffffffffffff

public export
CSVField a => CSVField (Maybe a) where
  read "" = Just Nothing
  read s  = Just <$> read s

--------------------------------------------------------------------------------
--          CSVError
--------------------------------------------------------------------------------

public export
data CSVError : Type where
  FieldError           : (line, column : Nat) -> (str : String) -> CSVError
  UnexpectedEndOfInput : (line, column : Nat) -> CSVError
  ExpectedEndOfInput   : (line, column : Nat) -> CSVError
  Append               : CSVError -> CSVError -> CSVError

public export
Semigroup CSVError where
  (<+>) = Append

public export
readField : CSVField a => (line, col : Nat) -> String -> Validated CSVError a
readField line col str =
  maybe (Invalid $ FieldError line col str) Valid (read str)

--------------------------------------------------------------------------------
--          CSVLine
--------------------------------------------------------------------------------

public export
interface CSVLine a where
  decodeAt : (line, col : Nat) -> List String -> Validated CSVError a

public export
CSVLine (HList []) where
  decodeAt _ _ [] = Valid Nil
  decodeAt l c _  = Invalid (ExpectedEndOfInput l c)

public export
CSVField t => CSVLine (HList ts) => CSVLine (HList (t :: ts)) where
  decodeAt l c []        = Invalid (UnexpectedEndOfInput l c)
  decodeAt l c (s :: ss) = [| readField l c s :: decodeAt l (S c) ss |]

public export
decode : CSVLine a => (line : Nat) -> String -> Validated CSVError a
decode line = decodeAt line 1 . forget . split (',' ==)

public export
hdecode :  (0 ts : List Type)
        -> CSVLine (HList ts)
        => (line : Nat)
        -> String
        -> Validated CSVError (HList ts)
hdecode _ = decode
