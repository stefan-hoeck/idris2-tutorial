module Solutions.Functions1

--------------------------------------------------------------------------------
--          Exercise 1
--------------------------------------------------------------------------------

square : Integer -> Integer
square n = n * n

testSquare : (Integer -> Bool) -> Integer -> Bool
testSquare fun = fun . square

twice : (Integer -> Integer) -> Integer -> Integer
twice f = f . f

--------------------------------------------------------------------------------
--          Exercise 2
--------------------------------------------------------------------------------

isEven : Integer -> Bool
isEven n = (n `mod` 2) == 0

isOdd : Integer -> Bool
isOdd = not . isEven

--------------------------------------------------------------------------------
--          Exercise 3
--------------------------------------------------------------------------------

isSquareOf : Integer -> Integer -> Bool
isSquareOf n x = n == x * x

--------------------------------------------------------------------------------
--          Exercise 4
--------------------------------------------------------------------------------

isSmall : Integer -> Bool
isSmall n = n <= 100

--------------------------------------------------------------------------------
--          Exercise 5
--------------------------------------------------------------------------------

absIsSmall : Integer -> Bool
absIsSmall = isSmall . abs

--------------------------------------------------------------------------------
--          Exercise 6
--------------------------------------------------------------------------------

and : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool
and f1 f2 n = f1 n && f2 n

or : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool
or f1 f2 n = f1 n || f2 n

negate : (Integer -> Bool) -> Integer -> Bool
negate f = not . f

--------------------------------------------------------------------------------
--          Exercise 7
--------------------------------------------------------------------------------

(&&) : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool
(&&) = and

(||) : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool
(||) = or

not : (Integer -> Bool) -> Integer -> Bool
not = negate
