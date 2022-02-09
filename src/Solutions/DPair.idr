module Solutions.DPair

import Control.Monad.State

import Data.DPair
import Data.Either
import Data.HList
import Data.List
import Data.List1
import Data.Singleton
import Data.String
import Data.Vect

import Text.CSV

import System.File

%default total

--------------------------------------------------------------------------------
--          Dependent Pairs
--------------------------------------------------------------------------------

-- 1

filterVect : (a -> Bool) -> Vect m a -> (n ** Vect n a)
filterVect f []        = (_ ** [])
filterVect f (x :: xs) = case f x of
  True  => let (_ ** ys) = filterVect f xs in (_ ** x :: ys)
  False => filterVect f xs

-- 2

mapMaybeVect : (a -> Maybe b) -> Vect m a -> (n ** Vect n b)
mapMaybeVect f []        = (_ ** [])
mapMaybeVect f (x :: xs) = case f x of
  Just v  => let (_ ** vs) = mapMaybeVect f xs in (_ ** v :: vs)
  Nothing => mapMaybeVect f xs

-- 3

dropWhileVect : (a -> Bool) -> Vect m a -> Exists (\n => Vect n a)
dropWhileVect f []        = Evidence _ []
dropWhileVect f (x :: xs) = case f x of
  True  => dropWhileVect f xs
  False => Evidence _ (x :: xs)

-- 4

vectLength : Vect n a -> Singleton n
vectLength []        = Val 0
vectLength (x :: xs) = let Val k = vectLength xs in Val (S k)

dropWhileVect' : (a -> Bool) -> Vect m a -> (n ** Vect n a)
dropWhileVect' f xs =
  let Evidence _ ys = dropWhileVect f xs
      Val n         = vectLength ys
   in (n ** ys)

--------------------------------------------------------------------------------
--          Use Case: Nucleic Acids
--------------------------------------------------------------------------------

-- 1

data BaseType = DNABase | RNABase

data Nucleobase' : BaseType -> Type where
  Adenine'  : Nucleobase' b
  Cytosine' : Nucleobase' b
  Guanine'  : Nucleobase' b
  Thymine'  : Nucleobase' DNABase
  Uracile'  : Nucleobase' RNABase

RNA' : Type
RNA' = List (Nucleobase' RNABase)

DNA' : Type
DNA' = List (Nucleobase' DNABase)

Acid1 : Type
Acid1 = (b ** List (Nucleobase' b))

record Acid2 where
  constructor MkAcid2
  baseType : BaseType
  sequence : List (Nucleobase' baseType)

data Acid3 : Type where
  SomeRNA : RNA' -> Acid3
  SomeDNA : DNA' -> Acid3

nb12 : Acid1 -> Acid2
nb12 (fst ** snd) = MkAcid2 fst snd

nb21 : Acid2 -> Acid1
nb21 (MkAcid2 bt seq) = (bt ** seq)

nb13 : Acid1 -> Acid3
nb13 (DNABase ** snd) = SomeDNA snd
nb13 (RNABase ** snd) = SomeRNA snd

nb31 : Acid3 -> Acid1
nb31 (SomeRNA xs) = (RNABase ** xs)
nb31 (SomeDNA xs) = (DNABase ** xs)

-- 2

data Dir = Sense | Antisense

data Nucleobase : BaseType -> Dir -> Type where
  Adenine  : Nucleobase b d
  Cytosine : Nucleobase b d
  Guanine  : Nucleobase b d
  Thymine  : Nucleobase DNABase d
  Uracile  : Nucleobase RNABase d

RNA : Dir -> Type
RNA d = List (Nucleobase RNABase d)

DNA : Dir -> Type
DNA d = List (Nucleobase DNABase d)

-- 3

inverse : Dir -> Dir
inverse Sense     = Antisense
inverse Antisense = Sense

complementBase :  (b : BaseType)
               -> Nucleobase b dir
               -> Nucleobase b (inverse dir)
complementBase DNABase Adenine  = Thymine
complementBase RNABase Adenine  = Uracile
complementBase _       Cytosine = Guanine
complementBase _       Guanine  = Cytosine
complementBase _       Thymine  = Adenine
complementBase _       Uracile  = Adenine

complement :  (b : BaseType)
           -> List (Nucleobase b dir)
           -> List (Nucleobase b $ inverse dir)
complement b = map (complementBase b)

transcribeBase : Nucleobase DNABase Antisense -> Nucleobase RNABase Sense
transcribeBase Adenine  = Uracile
transcribeBase Cytosine = Guanine
transcribeBase Guanine  = Cytosine
transcribeBase Thymine  = Adenine

transcribe : DNA Antisense -> RNA Sense
transcribe = map transcribeBase

transcribeAny : (dir : Dir) -> DNA dir -> RNA Sense
transcribeAny Antisense = transcribe
transcribeAny Sense     = transcribe . complement _

-- 4

record NucleicAcid where
  constructor MkNucleicAcid
  baseType : BaseType
  dir      : Dir
  sequence : List (Nucleobase baseType dir)

-- 5

readAnyBase : {0 dir : _} -> Char -> Maybe (Nucleobase b dir)
readAnyBase 'A' = Just Adenine
readAnyBase 'C' = Just Cytosine
readAnyBase 'G' = Just Guanine
readAnyBase _   = Nothing

readRNABase : {0 dir : _} -> Char -> Maybe (Nucleobase RNABase dir)
readRNABase 'U' = Just Uracile
readRNABase c   = readAnyBase c

readDNABase : {0 dir : _} -> Char -> Maybe (Nucleobase DNABase dir)
readDNABase 'T' = Just Thymine
readDNABase c   = readAnyBase c

readRNA : String -> Maybe (dir : Dir ** RNA dir)
readRNA str = case forget $ split ('-' ==) str of
  ["5´",s,"3´"] => MkDPair Sense     <$> traverse readRNABase (unpack s)
  ["3´",s,"5´"] => MkDPair Antisense <$> traverse readRNABase (unpack s)
  _             => Nothing

readDNA : String -> Maybe (dir : Dir ** DNA dir)
readDNA str = case forget $ split ('-' ==) str of
  ["5´",s,"3´"] => MkDPair Sense     <$> traverse readDNABase (unpack s)
  ["3´",s,"5´"] => MkDPair Antisense <$> traverse readDNABase (unpack s)
  _             => Nothing

-- 6

preSuf : Dir -> (String,String)
preSuf Sense     = ("5´-", "-3´")
preSuf Antisense = ("3´-", "-5´")

encodeBase : Nucleobase c d -> Char
encodeBase Adenine  = 'A'
encodeBase Cytosine = 'C'
encodeBase Guanine  = 'G'
encodeBase Thymine  = 'T'
encodeBase Uracile  = 'U'

encode : (dir : Dir) -> List (Nucleobase b dir) -> String
encode dir seq =
  let (pre,suf) = preSuf dir
   in pre ++ pack (map encodeBase seq) ++ suf

-- 7

public export
data InputError : Type where
  UnknownBaseType : String -> InputError
  InvalidSequence : String -> InputError

readAcid :  (b : BaseType)
         -> String
         -> Either InputError (d ** List $ Nucleobase b d)
readAcid b str =
  let err = InvalidSequence str
   in case b of
        DNABase => maybeToEither err $ readDNA str
        RNABase => maybeToEither err $ readRNA str

toAcid : (b : BaseType) -> (d ** List $ Nucleobase b d) -> NucleicAcid
toAcid b (d ** seq) = MkNucleicAcid b d seq

getNucleicAcid : IO (Either InputError NucleicAcid)
getNucleicAcid = do
  baseString <- getLine
  case baseString of
    "DNA" => map (toAcid _) . readAcid DNABase <$> getLine
    "RNA" => map (toAcid _) . readAcid RNABase <$> getLine
    _     => pure $ Left (UnknownBaseType baseString)

printRNA : RNA Sense -> IO ()
printRNA = putStrLn . encode _

transcribeProg : IO ()
transcribeProg = do
  Right (MkNucleicAcid b d seq) <- getNucleicAcid
    | Left (InvalidSequence str) => putStrLn $ "Invalid sequence: " ++ str
    | Left (UnknownBaseType str) => putStrLn $ "Unknown base type: " ++ str
  case b of
    DNABase => printRNA $ transcribeAny d seq
    RNABase => case d of
      Sense     => printRNA seq
      Antisense => printRNA $ complement _ seq

--------------------------------------------------------------------------------
--          Use Case: CSV Files with a Schema
--------------------------------------------------------------------------------

-- A lot of code was copy-pasted from the chapter's text and is, therefore
-- not very interesting. I tried to annotate the new parts with some hints
-- for better understanding. Also, instead of grouping code by exercise number,
-- I organized it thematically.



--   *** Types ***



-- I used an indexed type here to make sure, data
-- constructor `Optional` takes only non-nullary types
-- as arguments. As noted in exercise 3, having a nesting
-- of nullary types does not make sense without a way to
-- distinguish between a `Nothing` and a `Just Nothing`,
-- both of which would be encoded as the empty string.
-- For `Finite`, we have to add `n` as an argument to the
-- data constructor, so we can use it to decode values
-- of type `Fin n`.
data ColType0 : (nullary : Bool) -> Type where
  B8       : ColType0 b
  B16      : ColType0 b
  B32      : ColType0 b
  B64      : ColType0 b
  I8       : ColType0 b
  I16      : ColType0 b
  I32      : ColType0 b
  I64      : ColType0 b
  Str      : ColType0 b
  Boolean  : ColType0 b
  Float    : ColType0 b
  Natural  : ColType0 b
  BigInt   : ColType0 b
  Finite   : Nat -> ColType0 b
  Optional : ColType0 False -> ColType0 True

-- This is the type used in schemata, where nullary types
-- are explicitly allowed.
ColType : Type
ColType = ColType0 True

Schema : Type
Schema = List ColType

-- The only interesting new parts are the last two
-- lines. They should be pretty self-explanatory.
IdrisType : ColType0 b -> Type
IdrisType B8           = Bits8
IdrisType B16          = Bits16
IdrisType B32          = Bits32
IdrisType B64          = Bits64
IdrisType I8           = Int8
IdrisType I16          = Int16
IdrisType I32          = Int32
IdrisType I64          = Int64
IdrisType Str          = String
IdrisType Boolean      = Bool
IdrisType Float        = Double
IdrisType Natural      = Nat
IdrisType BigInt       = Integer
IdrisType (Finite n)   = Fin n
IdrisType (Optional t) = Maybe $ IdrisType t

Row : Schema -> Type
Row = HList . map IdrisType

record Table where
  constructor MkTable
  schema : Schema
  size   : Nat
  rows   : Vect size (Row schema)

data Error : Type where
  ExpectedEOI    : (pos : Nat) -> String -> Error
  ExpectedLine   : Error
  InvalidCell    : (row, col : Nat) -> ColType0 b -> String -> Error
  NoNat          : String -> Error
  OutOfBounds    : (size : Nat) -> (index : Nat) -> Error
  ReadError      : (path : String) -> FileError -> Error
  SizeLimit      : (path : String) -> Error
  UnexpectedEOI  : (pos : Nat) -> String -> Error
  UnknownCommand : String -> Error
  UnknownType    : (pos : Nat) -> String -> Error
  WriteError     : (path : String) -> FileError -> Error

-- Oh, the type of `Query` is a nice one. :-)
-- `PrintTable`, on the other hand, is trivial.
-- The save and load commands are special: They will
-- already have carried out their tasks after parsing.
-- This allow us to keep `applyCommand` pure.
data Command : (t : Table) -> Type where
  PrintSchema : Command t
  PrintSize   : Command t
  PrintTable  : Command t
  Load        : Table -> Command t
  Save        : Command t
  New         : (newSchema : Schema) -> Command t
  Prepend     : Row (schema t) -> Command t
  Get         : Fin (size t) -> Command t
  Delete      : Fin (size t) -> Command t
  Quit        : Command t
  Query       :  (ix  : Fin (length $ schema t))
              -> (val : IdrisType $ indexList (schema t) ix)
              -> Command t



--   *** Core Functionality ***



-- Compares two values for equality.
eq : (c : ColType0 b) -> IdrisType c -> IdrisType c -> Bool
eq B8           x        y        = x == y
eq B16          x        y        = x == y
eq B32          x        y        = x == y
eq B64          x        y        = x == y
eq I8           x        y        = x == y
eq I16          x        y        = x == y
eq I32          x        y        = x == y
eq I64          x        y        = x == y
eq Str          x        y        = x == y
eq Boolean      x        y        = x == y
eq Float        x        y        = x == y
eq Natural      x        y        = x == y
eq BigInt       x        y        = x == y
eq (Finite k)   x        y        = x == y
eq (Optional z) (Just x) (Just y) = eq z x y
eq (Optional z) Nothing  Nothing  = True
eq (Optional z) _        _        = False

-- Note: It would have been quite a bit easier to type and
-- implement this, had we used a heterogeneous vector instead
-- of a heterogeneous list for encoding table rows. However,
-- I still think it's pretty cool that this type checks!
eqAt :  (ts  : Schema)
     -> (ix  : Fin $ length ts)
     -> (val : IdrisType $ indexList ts ix)
     -> (row : Row ts)
     -> Bool
eqAt (x :: _)  FZ     val (v :: _)  = eq x val v
eqAt (_ :: xs) (FS y) val (_ :: vs) = eqAt xs y val vs
eqAt []        _      _   _ impossible

-- Most new commands don't change the table,
-- so their cases are trivial. The exception is
-- `Load`, which replaces the table completely.
applyCommand : (t : Table) -> Command t -> Table
applyCommand t                 PrintSchema    = t
applyCommand t                 PrintSize      = t
applyCommand t                 PrintTable     = t
applyCommand t                 Save           = t
applyCommand _                 (Load t')      = t'
applyCommand _                 (New ts)       = MkTable ts _ []
applyCommand (MkTable ts n rs) (Prepend r)    = MkTable ts _ $ r :: rs
applyCommand t                 (Get x)        = t
applyCommand t                 Quit           = t
applyCommand t                 (Query ix val) = t
applyCommand (MkTable ts n rs) (Delete x)  = case n of
  S k => MkTable ts k (deleteAt x rs)
  Z   => absurd x



--   *** Parsers ***



zipWithIndex : Traversable t => t a -> t (Nat, a)
zipWithIndex = evalState 1 . traverse pairWithIndex
  where pairWithIndex : a -> State Nat (Nat,a)
        pairWithIndex v = (,v) <$> get <* modify S

fromCSV : String -> List String
fromCSV = forget . split (',' ==)

-- Reads a primitive (non-nullary) type. This is therefore
-- universally quantified over parameter `b`.
-- The only interesting part is the parsing of `finXYZ`,
-- where we `break` the string at the occurrence of
-- the first digit.
readPrim : Nat -> String -> Either Error (ColType0 b)
readPrim _ "b8"       = Right B8
readPrim _ "b16"      = Right B16
readPrim _ "b32"      = Right B32
readPrim _ "b64"      = Right B64
readPrim _ "i8"       = Right I8
readPrim _ "i16"      = Right I16
readPrim _ "i32"      = Right I32
readPrim _ "i64"      = Right I64
readPrim _ "str"      = Right Str
readPrim _ "boolean"  = Right Boolean
readPrim _ "float"    = Right Float
readPrim _ "natural"  = Right Natural
readPrim _ "bigint"   = Right BigInt
readPrim n s          =
  let err = Left $ UnknownType n s
   in case break isDigit s of
        ("fin",r) => maybe err (Right . Finite) $ parsePositive r
        _         => err

-- This is the parser for (possibly nullary) column types.
-- A nullary type is encoded as the corresponding non-nullary
-- type with a question mark appended. We therefore first check
-- for the presence of said question mark at the end of the string.
readColType : Nat -> String -> Either Error ColType
readColType n s = case reverse (unpack s) of
  '?' :: t => Optional <$> readPrim n (pack $ reverse t)
  _        => readPrim n s

readSchema : String -> Either Error Schema
readSchema = traverse (uncurry readColType) . zipWithIndex . fromCSV

readSchemaList : List String -> Either Error Schema
readSchemaList [s] = readSchema s
readSchemaList _   = Left ExpectedLine

-- For all except nullary types we can just use the `CSVField`
-- implementation for reading values.
-- For values of nullary types, we treat the empty string specially.
decodeF : (c : ColType0 b) -> String -> Maybe (IdrisType c)
decodeF B8           s  = read s
decodeF B16          s  = read s
decodeF B32          s  = read s
decodeF B64          s  = read s
decodeF I8           s  = read s
decodeF I16          s  = read s
decodeF I32          s  = read s
decodeF I64          s  = read s
decodeF Str          s  = read s
decodeF Boolean      s  = read s
decodeF Float        s  = read s
decodeF Natural      s  = read s
decodeF BigInt       s  = read s
decodeF (Finite k)   s  = read s
decodeF (Optional y) "" = Just Nothing
decodeF (Optional y) s  = Just <$> decodeF y s

decodeField : (row,col : Nat) -> (c : ColType0 b) -> String -> Either Error (IdrisType c)
decodeField row k c s = maybeToEither (InvalidCell row k c s) $ decodeF c s

decodeRow : {ts : _} -> (row : Nat) -> String -> Either Error (Row ts)
decodeRow row s = go 1 ts $ fromCSV s
  where go : Nat -> (cs : Schema) -> List String -> Either Error (Row cs)
        go k []       []         = Right []
        go k []       (_ :: _)   = Left $ ExpectedEOI k s
        go k (_ :: _) []         = Left $ UnexpectedEOI k s
        go k (c :: cs) (s :: ss) = [| decodeField row k c s :: go (S k) cs ss |]

decodeRows : {ts : _} -> List String -> Either Error (List $ Row ts)
decodeRows = traverse (uncurry decodeRow) . zipWithIndex

readFin : {n : _} -> String -> Either Error (Fin n)
readFin s = do
  k <- maybeToEither (NoNat s) $ parsePositive {a = Nat} s
  maybeToEither (OutOfBounds n k) $ natToFin k n

readCommand :  (t : Table) -> String -> Either Error (Command t)
readCommand _                "schema"  = Right PrintSchema
readCommand _                "size"    = Right PrintSize
readCommand _                "table"   = Right PrintTable
readCommand _                "quit"    = Right Quit
readCommand (MkTable ts n _) s         = case words s of
  ["new",    str]    => New     <$> readSchema str
  "add" ::   ss      => Prepend <$> decodeRow 1 (unwords ss)
  ["get",    str]    => Get     <$> readFin str
  ["delete", str]    => Delete  <$> readFin str
  "query" :: n :: ss => do
    ix  <- readFin n
    val <- decodeField 1 1 (indexList ts ix) (unwords ss)
    pure $ Query ix val
  _                  => Left $ UnknownCommand s



--   *** Printers ***



toCSV : List String -> String
toCSV = concat . intersperse ","

-- We mark optional type by appending a question
-- mark after the corresponding non-nullary type.
showColType : ColType0 b -> String
showColType B8           = "b8"
showColType B16          = "b16"
showColType B32          = "b32"
showColType B64          = "b64"
showColType I8           = "i8"
showColType I16          = "i16"
showColType I32          = "i32"
showColType I64          = "i64"
showColType Str          = "str"
showColType Boolean      = "boolean"
showColType Float        = "float"
showColType Natural      = "natural"
showColType BigInt       = "bigint"
showColType (Finite n)   = "fin\{show n}"
showColType (Optional t) = showColType t ++ "?"

-- Again, only nullary values are treated specially. This
-- is another case of a dependent pattern match: We use
-- explicit pattern matches on the value to encode based
-- on the type calculated from the `ColType0 b` parameter.
-- There are few languages capable of expressing this as
-- cleanly as Idris does.
encodeField : (t : ColType0 b) -> IdrisType t -> String
encodeField B8           x        = show x
encodeField B16          x        = show x
encodeField B32          x        = show x
encodeField B64          x        = show x
encodeField I8           x        = show x
encodeField I16          x        = show x
encodeField I32          x        = show x
encodeField I64          x        = show x
encodeField Str          x        = x
encodeField Boolean      True     = "t"
encodeField Boolean      False    = "f"
encodeField Float        x        = show x
encodeField Natural      x        = show x
encodeField BigInt       x        = show x
encodeField (Finite k)   x        = show x
encodeField (Optional y) (Just v) = encodeField y v
encodeField (Optional y) Nothing  = ""

encodeFields : (ts : Schema) -> Row ts -> Vect (length ts) String
encodeFields []        []        = []
encodeFields (c :: cs) (v :: vs) = encodeField c v :: encodeFields cs vs

encodeTable : Table -> String
encodeTable (MkTable ts _ rows) =
  unlines . toList $ map (toCSV . toList . encodeFields ts) rows

encodeSchema : Schema -> String
encodeSchema = toCSV . map showColType

-- Pretty printing a table plus header. All cells are right-padded
-- with spaces to adjust their size to the cell with the longest
-- entry for each colum.
-- Value `lengths` is a `Vect n Nat` holding these lengths.
-- Here is an example of how the output looks like:
--
-- fin100 | boolean | natural | str         | bigint?
-- --------------------------------------------------
-- 88     | f       | 10      | stefan      |
-- 13     | f       | 10      | hock        | -100
-- 58     | t       | 1000    | hello world | -1234
--
-- Ideally, numeric values would be right-aligned, but since this
-- whole exercise is already quite long and complex, I refrained
-- from adding this luxury.
prettyTable :  {n : _}
            -> (header : Vect n String)
            -> (table  : Vect m (Vect n String))
            -> String
prettyTable h t =
  let -- vector holding the maximal length of each column
      lengths = foldl (zipWith maxLen) (replicate n Z) (h :: t)

      -- horizontal bar used to separate the header from the rows
      bar     = concat . intersperse "---" $ map (`replicate` '-') lengths
   in unlines . toList $ line lengths h :: bar :: map (line lengths) t

  where maxLen : Nat -> String -> Nat
        maxLen k = max k . length

        pad : Nat -> String -> String
        pad v = padRight v ' '

        -- given a vector of lengths, pads each string to the
        -- desired length, separating cells with a vertical bar.
        line : Vect n Nat -> Vect n String -> String
        line lengths = concat . intersperse " | " . zipWith pad lengths

printTable :  (cs   : List ColType)
           -> (rows : Vect n (Row cs))
           -> String
printTable cs rows =
  let header  = map showColType $ fromList cs
      table   = map (encodeFields cs) rows
   in prettyTable header table

allTypes : String
allTypes = concat
         . List.intersperse ", "
         . map (showColType {b = True})
         $ [B8,B16,B32,B64,I8,I16,I32,I64,Str,Boolean,Float]

showError : Error -> String
showError ExpectedLine = """
  Error when reading schema.
  Expected a single line of content.
  """

showError (UnknownCommand x) = """
  Unknown command: \{x}.
  Known commands are: clear, schema, size, table, new, add, get, delete, quit.
  """

showError (UnknownType pos x) = """
  Unknown type at position \{show pos}: \{x}.
  Known types are: \{allTypes}.
  """

showError (InvalidCell row col tpe x) = """
  Invalid value at row \{show row}, column \{show col}.
  Expected type: \{showColType tpe}.
  Value found: \{x}.
  """

showError (ExpectedEOI k x) = """
  Expected end of input.
  Position: \{show k}
  Input: \{x}
  """

showError (UnexpectedEOI k x) = """
  Unxpected end of input.
  Position: \{show k}
  Input: \{x}
  """

showError (OutOfBounds size index) = """
  Index out of bounds.
  Size of table: \{show size}
  Index: \{show index}
  Note: Indices start at zero.
  """

showError (WriteError path err) = """
  Error when writing file \{path}.
  Message: \{show err}
  """

showError (ReadError path err) = """
  Error when reading file \{path}.
  Message: \{show err}
  """

showError (SizeLimit path) = """
  Error when reading file \{path}.
  The size limit of 1'000'000 lines was exceeded.
  """

showError (NoNat x) = "Not a natural number: \{x}"

result :  (t : Table) -> Command t -> String
result t PrintSchema    = "Current schema: \{encodeSchema t.schema}"
result t PrintSize      = "Current size: \{show t.size}"
result t PrintTable     = "Table:\n\n\{printTable t.schema t.rows}"
result _ Save           = "Table written to disk."
result _ (Load t)       = "Table loaded. Schema: \{encodeSchema t.schema}"
result _ (New ts)       = "Created table. Schema: \{encodeSchema ts}"
result t (Prepend r)    = "Row prepended:\n\n\{printTable t.schema [r]}"
result _ (Delete x)     = "Deleted row: \{show x}."
result _ Quit           = "Goodbye."
result t (Query ix val) =
  let (_ ** rs) = filter (eqAt t.schema ix val) t.rows
   in "Result:\n\n\{printTable t.schema rs}"
result t (Get x)        =
  "Row \{show x}:\n\n\{printTable t.schema [index x t.rows]}"



--   *** File IO ***



-- We use total function `readFilePage` here. This allows us
-- to limit the total number of lines to prevent us from blowing
-- up our computer's memory. Note, that this might still be possible
-- for instance, when trying to read infinie streams without line breaks
-- like /dev/zero.
load :  (path   : String)
     -> (decode : List String -> Either Error a)
     -> IO (Either Error a)
load path decode = do
  Right (True, ls) <- readFilePage 0 (limit 1000000) path
    | Right (False,_) => pure $ Left (SizeLimit path)
    | Left err        => pure $ Left (ReadError path err)
  pure $ decode (map trim $ filter (not . null) ls)

write : (path : String) -> (content : String) -> IO (Either Error ())
write path content = mapFst (WriteError path) <$> writeFile path content

namespace IOEither
  export
  (>>=) : IO (Either err a) -> (a -> IO (Either err b)) -> IO (Either err b)
  ioa >>= f = Prelude.(>>=) ioa (either (pure . Left) f)

  export
  (>>) : IO (Either err ()) -> IO (Either err a) -> IO (Either err a)
  (>>) x y = x >>= const y

  export
  pure : a -> IO (Either err a)
  pure = Prelude.pure . Right

readCommandIO : (t : Table) -> String -> IO (Either Error (Command t))
readCommandIO t s = case words s of
  ["save", pth] => IOEither.do
    write (pth ++ ".schema") (encodeSchema t.schema)
    write (pth ++ ".csv") (encodeTable t)
    pure Save

  ["load", pth] => IOEither.do
    schema <- load (pth ++ ".schema") readSchemaList
    rows   <- load (pth ++ ".csv") (decodeRows {ts = schema})
    pure . Load $ MkTable schema (length rows) (fromList rows)

  _ => Prelude.pure $ readCommand t s



--   *** Main Loop ***



covering
runProg : Table -> IO ()
runProg t = do
  putStr "Enter a command: "
  str <- getLine
  cmd <- readCommandIO t str
  case cmd of
    Left err   => putStrLn (showError err) >> runProg t
    Right Quit => putStrLn (result t Quit)
    Right cmd  => putStrLn (result t cmd) >>
                  runProg (applyCommand t cmd)

covering
main : IO ()
main = runProg $ MkTable [] _ []
