module Solutions.DataTypes

-- If all or almost all functions in a module are provably
-- total, it is convenient to add the following pragma
-- at the top of the module. It is then no longer necessary
-- to annotate each function with the `total` keyword.
%default total

--------------------------------------------------------------------------------
--          Enumerations
--------------------------------------------------------------------------------

-- 1
and : Bool -> Bool -> Bool
and True  b = b
and False _ = False

or : Bool -> Bool -> Bool
or True  _ = True
or False b = b

--2
data UnitOfTime = Second | Minute | Hour | Day | Week

toSeconds : UnitOfTime -> Integer -> Integer
toSeconds Second y = y
toSeconds Minute y = 60 * y
toSeconds Hour y   = 60 * 60 * y
toSeconds Day y    = 24 * 60 * 60 * y
toSeconds Week y   = 7 * 24 * 60 * 60 * y

fromSeconds : UnitOfTime -> Integer -> Integer
fromSeconds u s = s `div` toSeconds u 1

convert : UnitOfTime -> Integer -> UnitOfTime -> Integer
convert u1 n u2 = fromSeconds u2 (toSeconds u1 n)

--3

data Element = H | C | N | O | F

atomicMass : Element -> Double
atomicMass H = 1.008
atomicMass C = 12.011
atomicMass N = 14.007
atomicMass O = 15.999
atomicMass F = 18.9984


--------------------------------------------------------------------------------
--          Sum Types
--------------------------------------------------------------------------------

data Title = Mr | Mrs | Other String

eqTitle : Title -> Title -> Bool
eqTitle Mr        Mr        = True
eqTitle Mrs       Mrs       = True
eqTitle (Other x) (Other y) = x == y
eqTitle _         _         = False

isOther : Title -> Bool
isOther (Other _) = True
isOther _         = False

data LoginError = UnknownUser String | InvalidPassword | InvalidKey

showError : LoginError -> String
showError (UnknownUser x) = "Unknown user: " ++ x
showError InvalidPassword = "Invalid password"
showError InvalidKey      = "Invalid key"

--------------------------------------------------------------------------------
--          Records
--------------------------------------------------------------------------------

-- 1
record TimeSpan where
  constructor MkTimeSpan
  unit  : UnitOfTime
  value : Integer

timeSpanToSeconds : TimeSpan -> Integer
timeSpanToSeconds (MkTimeSpan unit value) = toSeconds unit value

-- 2
eqTimeSpan : TimeSpan -> TimeSpan -> Bool
eqTimeSpan x y = timeSpanToSeconds x == timeSpanToSeconds y

-- alternative equality check using `on` from the Idris Prelude
eqTimeSpan' : TimeSpan -> TimeSpan -> Bool
eqTimeSpan' = (==) `on` timeSpanToSeconds

-- 3
showUnit : UnitOfTime -> String
showUnit Second = "s"
showUnit Minute = "min"
showUnit Hour   = "h"
showUnit Day    = "d"
showUnit Week   = "w"

prettyTimeSpan : TimeSpan -> String
prettyTimeSpan (MkTimeSpan Second v) = show v ++ " s"
prettyTimeSpan (MkTimeSpan u v)      =
  show v ++ " " ++ showUnit u ++ "(" ++ show (toSeconds u v) ++ " s)"

-- 4
compareUnit : UnitOfTime -> UnitOfTime -> Ordering
compareUnit = compare `on` (\x => toSeconds x 1)

minUnit : UnitOfTime -> UnitOfTime -> UnitOfTime
minUnit x y = case compareUnit x y of
  LT => x
  _  => y

addTimeSpan : TimeSpan -> TimeSpan -> TimeSpan
addTimeSpan (MkTimeSpan u1 v1) (MkTimeSpan u2 v2) =
  case minUnit u1 u2 of
    u => MkTimeSpan u (convert u1 v1 u + convert u2 v2 u)

--------------------------------------------------------------------------------
--          Generic Data Types
--------------------------------------------------------------------------------

-- 1
mapMaybe : (a -> b) -> Maybe a -> Maybe b
mapMaybe _ Nothing  = Nothing
mapMaybe f (Just x) = Just (f x)

appMaybe : Maybe (a -> b) -> Maybe a -> Maybe b
appMaybe (Just f) (Just v) = Just (f v)
appMaybe _        _        = Nothing

bindMaybe : Maybe a -> (a -> Maybe b) -> Maybe b
bindMaybe Nothing  _ = Nothing
bindMaybe (Just x) f = f x

filterMaybe : (a -> Bool) -> Maybe a -> Maybe a
filterMaybe f Nothing  = Nothing
filterMaybe f (Just x) = if (f x) then Just x else Nothing

first : Maybe a -> Maybe a -> Maybe a
first Nothing  y = y
first (Just x) _ = Just x

last : Maybe a -> Maybe a -> Maybe a
last x y = first y x

foldMaybe : (acc -> el -> acc) -> acc -> Maybe el -> acc
foldMaybe f x = maybe x (f x)

-- 2
mapEither : (a -> b) -> Either e a -> Either e b
mapEither _ (Left x)  = Left x
mapEither f (Right x) = Right (f x)

appEither : Either e (a -> b) -> Either e a -> Either e b
appEither (Left x)  _         = Left x
appEither (Right _) (Left x)  = Left x
appEither (Right f) (Right v) = Right (f v)

bindEither : Either e a -> (a -> Either e b) -> Either e b
bindEither (Left x)  _ = Left x
bindEither (Right x) f = f x

firstEither : (e -> e -> e) -> Either e a -> Either e a -> Either e a
firstEither fun (Left e1) (Left e2) = Left (fun e1 e2)
firstEither _   (Left e1) y         = y
firstEither _   (Right x) _         = Right x

-- instead of implementing this via pattern matching, we use
-- firstEither and swap the arguments. Since this would mean that
-- in the case of two `Left`s the errors would be in the wrong
-- order, we have to swap the arguments of `fun` as well.
-- Function `flip` from the prelude does this for us.
lastEither : (e -> e -> e) -> Either e a -> Either e a -> Either e a
lastEither fun x y = firstEither (flip fun) y x

fromEither : (e -> c) -> (a -> c) -> Either e a -> c
fromEither f _ (Left x)  = f x
fromEither _ g (Right x) = g x

-- 3
mapList : (a -> b) -> List a -> List b
mapList f Nil       = Nil
mapList f (x :: xs) = f x :: mapList f xs

filterList : (a -> Bool) -> List a -> List a
filterList f Nil       = Nil
filterList f (x :: xs) =
  if f x then x :: filterList f xs else filterList f xs

headMaybe : List a -> Maybe a
headMaybe Nil      = Nothing
headMaybe (x :: _) = Just x

tailMaybe : List a -> Maybe (List a)
tailMaybe Nil       = Nothing
tailMaybe (x :: xs) = Just xs

lastMaybe : List a -> Maybe a
lastMaybe Nil        = Nothing
lastMaybe (x :: Nil) = Just x
lastMaybe (_ :: xs)  = lastMaybe xs

initMaybe : List a -> Maybe (List a)
initMaybe Nil        = Nothing
initMaybe (x :: Nil) = Just Nil
initMaybe (x :: xs)  = mapMaybe (x ::) (initMaybe xs)

foldList : (acc -> el -> acc) -> acc -> List el -> acc
foldList fun vacc Nil       = vacc
foldList fun vacc (x :: xs) = foldList fun (fun vacc x) xs

-- 4
record Client where
  constructor MkClient
  name          : String
  title         : Title
  age           : Bits8
  passwordOrKey : Either Bits64 String

data Credentials = Password String Bits64 | Key String String

login1 : Client -> Credentials -> Either LoginError Client
login1 c (Password u y) =
  if c.name == u then
    if c.passwordOrKey == Left y then Right c else Left InvalidPassword
  else Left (UnknownUser u)

login1 c (Key u x) =
  if c.name == u then
    if c.passwordOrKey == Right x then Right c else Left InvalidKey
  else Left (UnknownUser u)

login : List Client -> Credentials -> Either LoginError Client
login Nil       (Password u _) = Left (UnknownUser u)
login Nil       (Key u _)      = Left (UnknownUser u)
login (x :: xs) cs             = case login1 x cs of
  Right c               => Right c
  Left  InvalidPassword => Left InvalidPassword
  Left  InvalidKey      => Left InvalidKey
  Left _                => login xs cs

--5

formulaMass : List (Element,Nat) -> Double
formulaMass []             = 0
formulaMass ((e, n) :: xs) = atomicMass e * cast n + formulaMass xs


