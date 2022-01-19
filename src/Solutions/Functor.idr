module Solutions.Functor

import Data.List1
import Data.String
import Data.Vect

%default total

--------------------------------------------------------------------------------
--          Code Required from the Turoial
--------------------------------------------------------------------------------

interface Functor' (0 f : Type -> Type) where
  map' : (a -> b) -> f a -> f b

interface Functor' f => Applicative' f where
  app   : f (a -> b) -> f a -> f b
  pure' : a -> f a

data Gender = Male | Female | Other

record Name where
  constructor MkName
  value : String

record Email where
  constructor MkEmail
  value : String

record Password where
  constructor MkPassword
  value : String

record User where
  constructor MkUser
  firstName : Name
  lastName  : Name
  age       : Nat
  email     : Maybe Email
  gender    : Gender
  password  : Password

interface CSVField a where
  read : String -> Maybe a

CSVField Gender where
  read "m" = Just Male
  read "f" = Just Female
  read "o" = Just Other
  read _   = Nothing

CSVField Bool where
  read "t" = Just True
  read "f" = Just False
  read _   = Nothing

CSVField Nat where
  read = parsePositive

CSVField Integer where
  read = parseInteger

CSVField Double where
  read = parseDouble

CSVField a => CSVField (Maybe a) where
  read "" = Just Nothing
  read s  = Just <$> read s

readIf : (String -> Bool) -> (String -> a) -> String -> Maybe a
readIf p mk s = if p s then Just (mk s) else Nothing

isValidName : String -> Bool
isValidName s =
  let len = length s
   in 0 < len && len <= 100 && all isAlpha (unpack s)

CSVField Name where
  read = readIf isValidName MkName

isEmailChar : Char -> Bool
isEmailChar '.' = True
isEmailChar '@' = True
isEmailChar c   = isAlphaNum c

isValidEmail : String -> Bool
isValidEmail s =
  let len = length s
   in 0 < len && len <= 100 && all isEmailChar (unpack s)

CSVField Email where
  read = readIf isValidEmail MkEmail

isPasswordChar : Char -> Bool
isPasswordChar ' ' = True
isPasswordChar c   = not (isControl c) && not (isSpace c)

isValidPassword : String -> Bool
isValidPassword s =
  let len = length s
   in 8 < len && len <= 100 && all isPasswordChar (unpack s)

CSVField Password where
  read = readIf isValidPassword MkPassword

data HList : (ts : List Type) -> Type where
  Nil  : HList Nil
  (::) : (v : t) -> (vs : HList ts) -> HList (t :: ts)

--------------------------------------------------------------------------------
--          Functor
--------------------------------------------------------------------------------

-- 1

Functor' Maybe where
  map' _ Nothing  = Nothing
  map' f (Just v) = Just $ f v

Functor' List where
  map' _ []        = []
  map' f (x :: xs) = f x :: map f xs

Functor' List1 where
  map' f (h ::: t) = f h ::: map' f t

Functor' (Vect n) where
  map' _ []        = []
  map' f (x :: xs) = f x :: map f xs

Functor' (Either e) where
  map' _ (Left ve)  = Left ve
  map' f (Right va) = Right $ f va

Functor' (Pair e) where
  map' f (ve,va) = (ve, f va)

-- 2

[Prod] Functor f => Functor g => Functor (\a => (f a, g a)) where
  map fun (fa, ga) = (map fun fa, map fun ga)

-- 3

record Identity a where
  constructor Id
  value : a

Functor Identity where
  map f (Id va) = Id $ f va

-- 4

record Const (e,a : Type) where
  constructor MkConst
  value : e

Functor (Const e) where
  map _ (MkConst v) = MkConst v

-- 5

data Crud : (i : Type) -> (a : Type) -> Type where
  Create : (value : a) -> Crud i a
  Update : (id : i) -> (value : a) -> Crud i a
  Read   : (id : i) -> Crud i a
  Delete : (id : i) -> Crud i a

Functor (Crud i) where
  map f (Create value)    = Create $ f value
  map f (Update id value) = Update id $ f value
  map _ (Read id)         = Read id
  map _ (Delete id)       = Delete id

-- 6

data Response : (e, i, a : Type) -> Type where
  Created : (id : i) -> (value : a) -> Response e i a
  Updated : (id : i) -> (value : a) -> Response e i a
  Found   : (values : List a) -> Response e i a
  Deleted : (id : i) -> Response e i a
  Error   : (err : e) -> Response e i a

Functor (Response e i) where
  map f (Created id value) = Created id $ f value
  map f (Updated id value) = Updated id $ f value
  map f (Found values)     = Found $ map f values
  map _ (Deleted id)       = Deleted id
  map _ (Error err)        = Error err


-- 7

data Validated : (e,a : Type) -> Type where
  Invalid : (err : e) -> Validated e a
  Valid   : (val : a) -> Validated e a

Functor (Validated e) where
  map _ (Invalid err) = Invalid err
  map f (Valid val)   = Valid $ f val

--------------------------------------------------------------------------------
--          Applicative
--------------------------------------------------------------------------------

-- 1

Applicative' (Either e) where
  pure' = Right
  app (Right f) (Right v) = Right $ f v
  app (Left ve) _         = Left ve
  app _         (Left ve) = Left ve

Applicative Identity where
  pure = Id
  Id f <*> Id v = Id $ f v

-- 2

{n : _} -> Applicative' (Vect n) where
  pure' = replicate n
  app []        []        = []
  app (f :: fs) (v :: vs) = f v :: app fs vs

-- 3

Monoid e => Applicative' (Pair e) where
  pure' v = (neutral, v)
  app (e1,f) (e2,v) = (e1 <+> e2, f v)

-- 4

Monoid e => Applicative (Const e) where
  pure _ = MkConst neutral
  MkConst e1 <*> MkConst e2 = MkConst $ e1 <+> e2

-- 5

Semigroup e => Applicative (Validated e) where
  pure = Valid
  Valid   f  <*> Valid v    = Valid $ f v
  Valid   _  <*> Invalid ve = Invalid ve
  Invalid e1 <*> Invalid e2 = Invalid $ e1 <+> e2
  Invalid ve <*> Valid _    = Invalid ve

-- 6

data CSVError : Type where
  FieldError           : (line, column : Nat) -> (str : String) -> CSVError
  UnexpectedEndOfInput : (line, column : Nat) -> CSVError
  ExpectedEndOfInput   : (line, column : Nat) -> CSVError
  App                  : (fst, snd : CSVError) -> CSVError

Semigroup CSVError where
  (<+>) = App

-- 7

readField : CSVField a => (line, column : Nat) -> String -> Validated CSVError a
readField line col str =
  maybe (Invalid $ FieldError line col str) Valid (read str)

toVect : (n : Nat) -> (line, col : Nat) -> List a -> Validated CSVError (Vect n a)
toVect 0     line _   []        = Valid []
toVect 0     line col _         = Invalid (ExpectedEndOfInput line col)
toVect (S k) line col []        = Invalid (UnexpectedEndOfInput line col)
toVect (S k) line col (x :: xs) = (x ::) <$> toVect k line (S col) xs

-- We can't use do notation here as we don't have an implementation
-- of Monad for `Validated`
readUser' : (line : Nat) -> List String -> Validated CSVError User
readUser' line ss = case toVect 6 line 0 ss of
  Valid [fn,ln,a,em,g,pw] =>
    [| MkUser (readField line 1 fn)
              (readField line 2 ln)
              (readField line 3 a)
              (readField line 4 em)
              (readField line 5 g)
              (readField line 6 pw) |]
  Invalid err => Invalid err

readUser : (line : Nat) -> String -> Validated CSVError User
readUser line = readUser' line . forget . split (',' ==)

interface CSVLine a where
  decodeAt : (line, col : Nat) -> List String -> Validated CSVError a

CSVLine (HList []) where
  decodeAt _ _ [] = Valid Nil
  decodeAt l c _  = Invalid (ExpectedEndOfInput l c)

CSVField t => CSVLine (HList ts) => CSVLine (HList (t :: ts)) where
  decodeAt l c []        = Invalid (UnexpectedEndOfInput l c)
  decodeAt l c (s :: ss) = [| readField l c s :: decodeAt l (S c) ss |]

decode : CSVLine a => (line : Nat) -> String -> Validated CSVError a
decode line = decodeAt line 1 . forget . split (',' ==)

hdecode :  (0 ts : List Type)
        -> CSVLine (HList ts)
        => (line : Nat)
        -> String
        -> Validated CSVError (HList ts)
hdecode _ = decode

-- 8

-- 8.1
head : HList (t :: ts) -> t
head (v :: _) = v

-- 8.2
tail : HList (t :: ts) -> HList ts
tail (_ :: t) = t

-- 8.3
(++) : HList xs -> HList ys -> HList (xs ++ ys)
[]        ++ ws = ws
(v :: vs) ++ ws = v :: (vs ++ ws)

-- 8.4
indexList : (as : List a) -> Fin (length as) -> a
indexList (x :: _)   FZ    = x
indexList (_ :: xs) (FS y) = indexList xs y
indexList []        x impossible

index : (ix : Fin (length ts)) -> HList ts -> indexList ts ix
index FZ     (v :: _)  = v
index (FS x) (_ :: vs) = index x vs
index ix [] impossible

-- 8.5
namespace HVect
  public export
  data HVect : (ts : Vect n Type) -> Type where
    Nil  : HVect Nil
    (::) : (v : t) -> (vs : HVect ts) -> HVect (t :: ts)

  public export
  head : HVect (t :: ts) -> t
  head (v :: _) = v
  
  public export
  tail : HVect (t :: ts) -> HVect ts
  tail (_ :: t) = t
  
  public export
  (++) : HVect xs -> HVect ys -> HVect (xs ++ ys)
  []        ++ ws = ws
  (v :: vs) ++ ws = v :: (vs ++ ws)
  
  public export
  index :  {0 n : Nat}
        -> {0 ts : Vect n Type}
        -> (ix : Fin n)
        -> HVect ts -> index ix ts
  index FZ     (v :: _)  = v
  index (FS x) (_ :: vs) = index x vs
  index ix [] impossible

-- 8.6

-- Note: We are usually not allowed to pattern match
-- on an erased argument. However, in this case, the
-- shape of `ts` follows from `n`, so we can pattern
-- match on `ts` to help Idris inferring the types.
--
-- Note also, that we create a `HVect` holding only empty
-- `Vect`s. We therefore only need to know about the length
-- of the type-level vector to implement this.
empties :  {n : Nat} -> {0 ts : Vect n Type} -> HVect (Vect 0 <$> ts)
empties {n = 0}   {ts = []}     = []
empties {n = S _} {ts = _ :: _} = [] :: empties

hcons :  {0 ts : Vect n Type}
      -> HVect ts
      -> HVect (Vect m <$> ts)
      -> HVect (Vect (S m) <$> ts)
hcons []        []        = []
hcons (v :: vs) (w :: ws) = (v :: w) :: hcons vs ws

htranspose :  {n : Nat}
           -> {0 ts : Vect n Type}
           -> Vect m (HVect ts)
           -> HVect (Vect m <$> ts)
htranspose []        = empties
htranspose (x :: xs) = hcons x (htranspose xs)

vects : Vect 3 (HVect [Bool, Nat, String])
vects = [[True, 100, "Hello"], [False, 0, "Idris"], [False, 2, "!"]]

vects' : HVect [Vect 3 Bool, Vect 3 Nat, Vect 3 String]
vects' = htranspose vects
