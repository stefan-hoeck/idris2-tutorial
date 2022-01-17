module Solutions.IO

import Data.List1
import Data.String

import System.File

%default total

--------------------------------------------------------------------------------
--          Pure Side Effects?
--------------------------------------------------------------------------------

-- 1
rep : (String -> String) -> IO ()
rep f = do
  s <- getLine
  putStrLn (f s)

-- 2
covering
repl : (String -> String) -> IO ()
repl f = do
  _ <- rep f
  repl f

-- 3
covering
replTill : (String -> Either String String) -> IO ()
replTill f = do
  s <- getLine
  case f s of
    Left  msg => putStrLn msg
    Right msg => do
      _ <- putStrLn msg
      replTill f

-- 4
data Error : Type where
  NotAnInteger    : (value : String) -> Error
  UnknownOperator : (value : String) -> Error
  ParseError      : (input : String) -> Error

dispError : Error -> String
dispError (NotAnInteger v)    = "Not an integer: " ++ v ++ "."
dispError (UnknownOperator v) = "Unknown operator: " ++ v ++ "."
dispError (ParseError v)      = "Invalid expression: " ++ v ++ "."

readInteger : String -> Either Error Integer
readInteger s = maybe (Left $ NotAnInteger s) Right $ parseInteger s

readOperator : String -> Either Error (Integer -> Integer -> Integer)
readOperator "+" = Right (+)
readOperator "*" = Right (*)
readOperator s   = Left (UnknownOperator s)

eval : String -> Either Error Integer
eval s =
  let [x,y,z]  := forget $ split isSpace s | _ => Left (ParseError s)
      Right v1 := readInteger x  | Left e => Left e
      Right op := readOperator y | Left e => Left e
      Right v2 := readInteger z  | Left e => Left e
   in Right $ op v1 v2

covering
exprProg : IO ()
exprProg = replTill prog
  where prog : String -> Either String String
        prog "done" = Left "Goodbye!"
        prog s      = Right . either dispError show $ eval s

-- 5
covering
replWith :  (state      : s)
         -> (next       : s -> String -> Either res s)
         -> (dispState  : s -> String)
         -> (dispResult : res -> s -> String)
         -> IO ()
replWith state next dispState dispResult = do
  _     <- putStrLn (dispState state)
  input <- getLine
  case next state input of
    Left  result => putStrLn (dispResult result state)
    Right state' => replWith state' next dispState dispResult

-- 6
data Abort : Type where
  NoNat : (input : String) -> Abort
  Done  : Abort

printSum : Nat -> String
printSum n =
  "Current sum: " ++ show n ++ "\nPlease enter a natural number:"

printRes : Abort -> Nat -> String
printRes (NoNat input) _ =
  "Not a natural number: " ++ input ++ ". Aborting..."
printRes Done k =
  "Final sum: " ++ show k ++ "\nHave a nice day."

readInput : Nat -> String -> Either Abort Nat
readInput _ "done" = Left Done
readInput n s      = case parseInteger {a = Integer} s of
  Nothing => Left $ NoNat s
  Just v  => if v >= 0 then Right (cast v + n) else Left (NoNat s)

covering
sumProg : IO ()
sumProg = replWith 0 readInput printSum printRes

--------------------------------------------------------------------------------
--          Do Blocks, Desugared
--------------------------------------------------------------------------------

-- 1
ex1a : IO String
ex1a = do
  s1 <- getLine
  s2 <- getLine
  s3 <- getLine
  pure $ s1 ++ reverse s2 ++ s3

ex1aBind : IO String
ex1aBind =
  getLine >>= (\s1 =>
    getLine >>= (\s2 =>
      getLine >>= (\s3 =>
        pure $ s1 ++ reverse s2 ++ s3
      )
    )
  )

ex1aBang : IO String
ex1aBang =
  pure $ !getLine ++ reverse !getLine ++ !getLine

ex1b : Maybe Integer
ex1b = do
  n1 <- parseInteger "12"
  n2 <- parseInteger "300"
  Just $ n1 + n2 * 100

ex1bBind : Maybe Integer
ex1bBind =
  parseInteger "12" >>= (\n1 =>
    parseInteger "300" >>= (\n2 =>
      Just $ n1 + n2 * 100
    )
  )

ex1bBang : Maybe Integer
ex1bBang =
  Just $ !(parseInteger "12") + !(parseInteger "300") * 100

-- 2
data List01 : (nonEmpty : Bool) -> Type -> Type where
  Nil  : List01 False a
  (::) : a -> List01 False a -> List01 ne a

head : List01 True a -> a
head (x :: _) = x

weaken : List01 ne a -> List01 False a
weaken []       = []
weaken (h :: t) = h :: t

map01 : (a -> b) -> List01 ne a -> List01 ne b
map01 _ []       = []
map01 f (x :: y) = f x :: map01 f y

tail : List01 True a -> List01 False a
tail (_ :: t) = weaken t

(++) : List01 ne1 a -> List01 ne2 a -> List01 (ne1 || ne2) a
(++) []       []       = []
(++) []       (h :: t) = h :: t
(++) (h :: t) xs       = h :: weaken (t ++ xs)

concat' : List01 ne1 (List01 ne2 a) -> List01 False a
concat' []       = []
concat' (x :: y) = weaken (x ++ concat' y)

concat :  {ne1, ne2 : _}
       -> List01 ne1 (List01 ne2 a)
       -> List01 (ne1 && ne2) a
concat {ne1 = True}  {ne2 = True}  (x :: y) = x ++ concat' y
concat {ne1 = True}  {ne2 = False} x        = concat' x
concat {ne1 = False} {ne2 = _}     x        = concat' x

namespace List01
  export
  (>>=) :  {ne1, ne2 : _}
        -> List01 ne1 a
        -> (a -> List01 ne2 b)
        -> List01 (ne1 && ne2) b
  as >>= f = concat (map01 f as)

--------------------------------------------------------------------------------
--          Working with Files
--------------------------------------------------------------------------------

-- 1
namespace IOErr
  export
  pure : a -> IO (Either e a)
  pure = pure . Right

  export
  fail : e -> IO (Either e a)
  fail = pure . Left

  export
  lift : IO a -> IO (Either e a)
  lift = map Right

  export
  catch : IO (Either e1 a) -> (e1 -> IO (Either e2 a)) -> IO (Either e2 a)
  catch io f = do
    Left err <- io | Right v => pure v
    f err

  export
  (>>=) : IO (Either e a) -> (a -> IO (Either e b)) -> IO (Either e b)
  io >>= f = Prelude.do
    Right v <- io | Left err => fail err
    f v

covering
countEmpty'' : (path : String) -> IO (Either FileError Nat)
countEmpty'' path = withFile path Read pure (go 0)
  where covering go : Nat -> File -> IO (Either FileError Nat)
        go k file = do
          False <- lift (fEOF file) | True => pure k
          "\n"  <- fGetLine file    | _  => go k file
          go (k + 1) file

-- 2
covering
countWords : (path : String) -> IO (Either FileError Nat)
countWords path = withFile path Read pure (go 0)
  where covering go : Nat -> File -> IO (Either FileError Nat)
        go k file = do
          False <- lift (fEOF file) | True => pure k
          s     <- fGetLine file
          go (k + length (words s)) file

-- 3
covering
withLines :  (path : String)
          -> (accum : s -> String -> s)
          -> (initialState : s)
          -> IO (Either FileError s)
withLines path accum ini = withFile path Read pure (go ini)
  where covering go : s -> File -> IO (Either FileError s)
        go st file = do
          False <- lift (fEOF file) | True => pure st
          line  <- fGetLine file
          go (accum st line) file

covering
countEmpty3 : (path : String) -> IO (Either FileError Nat)
countEmpty3 path = withLines path acc 0
  where acc : Nat -> String -> Nat
        acc k "\n" = k + 1
        acc k _    = k

covering
countWords2 : (path : String) -> IO (Either FileError Nat)
countWords2 path = withLines path (\n,s => n + length (words s)) 0

-- 4
covering
foldLines :  Monoid s
          => (path : String)
          -> (f    : String -> s)
          -> IO (Either FileError s)
foldLines path f = withLines path (\vs => (vs <+>) . f) neutral

-- 5

-- Instead of returning a triple of natural numbers,
-- it is better to make the semantics clear and use
-- a custom record type to store the result.
--
-- In a larger, more-complex application it might be
-- even better to make things truly type safe and
-- define a single field record together with an instance
-- of monoid for each kind of count.
record WC where
  constructor MkWC
  lines : Nat
  words : Nat
  chars : Nat

Semigroup WC where
  MkWC l1 w1 c1 <+> MkWC l2 w2 c2 = MkWC (l1 + l2) (w1 + w2) (c1 + c2)

Monoid WC where
  neutral = MkWC 0 0 0

covering
toWC : String -> WC
toWC s = MkWC 1 (length (words s)) (length s)

covering
wordCount : (path : String) -> IO (Either FileError WC)
wordCount path = foldLines path toWC

-- this is for testing the `wordCount` example.
covering
testWC : (path : String) -> IO ()
testWC path = Prelude.do
  Right (MkWC ls ws cs) <- wordCount path
    | Left err => putStrLn "Error: \{show err}"
  putStrLn "\{show ls} lines, \{show ws} words, \{show cs} characters"
