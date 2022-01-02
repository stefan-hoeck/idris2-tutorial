module Solutions.DataTypes

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

record TimeSpan where
  constructor MkTimeSpan
  unit  : UnitOfTime
  value : Integer

timeSpanToSeconds : TimeSpan -> Integer
timeSpanToSeconds (MkTimeSpan unit value) = toSeconds unit value

eqTimeSpan : TimeSpan -> TimeSpan -> Bool
eqTimeSpan x y = timeSpanToSeconds x == timeSpanToSeconds y

-- alternative equality check using `on` from the Idris Prelude
eqTimeSpan' : TimeSpan -> TimeSpan -> Bool
eqTimeSpan' = (==) `on` timeSpanToSeconds

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
