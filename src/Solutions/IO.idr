module Solutions.IO

import Data.List1
import Data.String

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
