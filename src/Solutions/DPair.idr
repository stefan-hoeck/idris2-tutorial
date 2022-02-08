module Solutions.DPair

import Data.DPair
import Data.Either
import Data.List1
import Data.Singleton
import Data.String
import Data.Vect

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

readRNABase : Char -> Maybe (Nucleobase RNABase dir)
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
