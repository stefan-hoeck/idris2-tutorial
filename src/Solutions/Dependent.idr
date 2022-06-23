module Solutions.Dependent

%default total

--------------------------------------------------------------------------------
--          Length-Indexed Lists
--------------------------------------------------------------------------------

data Vect : (len : Nat) -> Type -> Type where
  Nil  : Vect 0 a
  (::) : a -> Vect n a -> Vect (S n) a

-- 1
head : Vect (S n) a -> a
head (x :: _) = x
head Nil impossible

-- 2
tail : Vect (S n) a -> Vect n a
tail (_ :: xs) = xs
tail Nil impossible

-- 3
zipWith3 : (a -> b -> c -> d) -> Vect n a -> Vect n b -> Vect n c -> Vect n d
zipWith3 f []        []        []        = []
zipWith3 f (x :: xs) (y :: ys) (z :: zs) = f x y z :: zipWith3 f xs ys zs

-- 4
-- Since we only have a `Semigroup` constraint, we can't conjure
-- a value of type `a` out of nothing in case of an empty list.
-- We therefore have to return a `Nothing` in case of an empty list.
foldSemi : Semigroup a => List a -> Maybe a
foldSemi []        = Nothing
foldSemi (x :: xs) = Just . maybe x (x <+>) $ foldSemi xs

-- 5
-- the `Nil` case is impossible here, so unlike in Exercise 4,
-- we don't need to wrap the result in a `Maybe`.
-- However, we need to pattern match on the tail of the Vect to
-- decide whether to invoke `foldSemiVect` recursively or not
foldSemiVect : Semigroup a => Vect (S n) a -> a
foldSemiVect (x :: [])         = x
foldSemiVect (x :: t@(_ :: _)) = x <+> foldSemiVect t

-- 6
iterate : (n : Nat) -> (a -> a) -> a -> Vect n a
iterate 0     _ _ = Nil
iterate (S k) f v = v :: iterate k f (f v)

-- 7
generate : (n : Nat) -> (s -> (s,a)) -> s -> Vect n a
generate 0     _ _ = Nil
generate (S k) f v =
  let (v', va) = f v
   in va :: generate k f v'

-- 8
fromList : (as : List a) -> Vect (length as) a
fromList []        = []
fromList (x :: xs) = x :: fromList xs

-- 9
-- Lookup the type and implementation of functions `maybe` `const` and
-- try figuring out, what's going on here. An alternative implementation
-- would of course just pattern match on the argument.
maybeSize : Maybe a -> Nat
maybeSize = maybe 0 (const 1)

fromMaybe : (m : Maybe a) -> Vect (maybeSize m) a
fromMaybe Nothing  = []
fromMaybe (Just x) = [x]

--------------------------------------------------------------------------------
--          Fin: Safe Indexing into Vectors
--------------------------------------------------------------------------------

data Fin : (n : Nat) -> Type where
  FZ : {0 n : Nat} -> Fin (S n)
  FS : (k : Fin n) -> Fin (S n)

(++) : Vect m a -> Vect n a -> Vect (m + n) a
(++) []        ys = ys
(++) (x :: xs) ys = x :: (xs ++ ys)

replicate : (n : Nat) -> a -> Vect n a
replicate 0     _ = []
replicate (S k) x = x :: replicate k x

zipWith : (a -> b -> c) -> Vect n a -> Vect n b -> Vect n c
zipWith _ []        []        = []
zipWith f (x :: xs) (y :: ys) = f x y :: zipWith f xs ys



-- 1
update : (a -> a) -> Fin n -> Vect n a -> Vect n a
update f FZ     (x :: xs) = f x :: xs
update f (FS k) (x :: xs) = x :: update f k xs

-- 2
insert : a -> Fin (S n) -> Vect n a -> Vect (S n) a
insert v FZ     xs         = v :: xs
insert v (FS k) (x :: xs)  = x :: insert v k xs
insert v (FS k) []  impossible

-- 3
-- The trick here is to pattern match on the tail of the
-- vector in the `FS k` case and realize that an empty
-- tail is impossible. Otherwise we won't be able to
-- convince the type checker, that the vector's tail is
-- non-empty in the recursive case.
delete : Fin (S n) -> Vect (S n) a -> Vect n a
delete FZ     (_ :: xs)          = xs
delete (FS k) (x :: xs@(_ :: _)) = x :: delete k xs
delete (FS k) (x :: []) impossible

-- 4
safeIndexList : (xs : List a) -> Fin (length xs) -> a
safeIndexList (x :: _)  FZ     = x
safeIndexList (x :: xs) (FS k) = safeIndexList xs k
safeIndexList Nil _ impossible

-- 5
finToNat : Fin n -> Nat
finToNat FZ     = Z
finToNat (FS k) = S $ finToNat k

take : (k : Fin (S n)) -> Vect n a -> Vect (finToNat k) a
take FZ     x         = []
take (FS k) (x :: xs) = x :: take k xs

-- 6
minus : (n : Nat) -> Fin (S n) -> Nat
minus n FZ         = n
minus (S j) (FS k) = minus j k
minus 0 (FS k) impossible

-- 7
drop : (k : Fin (S n)) -> Vect n a -> Vect (minus n k) a
drop FZ     xs        = xs
drop (FS k) (_ :: xs) = drop k xs

-- 8
splitAt :  (k : Fin (S n))
        -> Vect n a
        -> (Vect (finToNat k) a, Vect (minus n k) a)
splitAt k xs = (take k xs, drop k xs)

--------------------------------------------------------------------------------
--          Compile-Time Computations
--------------------------------------------------------------------------------

-- 1
flattenList : List (List a) -> List a
flattenList []          = []
flattenList (xs :: xss) = xs ++ flattenList xss

flattenVect : Vect m (Vect n a) -> Vect (m * n) a
flattenVect []          = []
flattenVect (xs :: xss) = xs ++ flattenVect xss

-- 2
take' : (m : Nat) -> Vect (m + n) a -> Vect m a
take' 0     _         = []
take' (S k) (x :: xs) = x :: take' k xs
take' (S k) Nil impossible

drop' : (m : Nat) -> Vect (m + n) a -> Vect n a
drop' 0     xs        = xs
drop' (S k) (x :: xs) = drop' k xs
drop' (S k) Nil impossible

splitAt' : (m : Nat) -> Vect (m + n) a -> (Vect m a, Vect n a)
splitAt' m xs = (take' m xs, drop' m xs)

-- 3
-- Since we must call `replicate` in the `Nil` case, `k`
-- must be a non-erased argument. I used an implicit argument here,
-- since this reflects the type of the mathematical function
-- more closely.
--
-- Empty matrices probably don't make too much sense,
-- so we could also request at the type-level that `k` and `m`
-- are non-zero, in which case both values could be derived
-- by pattern matching on the vectors.
transpose : {k : _} -> Vect m (Vect k a) -> Vect k (Vect m a)
transpose []          = replicate k []
transpose (xs :: xss) = zipWith (::) xs (transpose xss)
