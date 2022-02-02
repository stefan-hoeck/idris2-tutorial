||| Data type `Validated` was introduced in chapter
||| *Functor and Friends*. It provides an error type
||| with the ability of error accumulation.
module Data.Validated

%default total

public export
data Validated : (e,a : Type) -> Type where
  Invalid : (err : e) -> Validated e a
  Valid   : (val : a) -> Validated e a

--------------------------------------------------------------------------------
--          Utilities
--------------------------------------------------------------------------------

public export
validated : (e -> b) -> (a -> b) -> Validated e a -> b
validated f _ (Invalid ve) = f ve
validated _ g (Valid va)   = g va

public export
fromEither : Either e a -> Validated e a
fromEither = either Invalid Valid

public export
toEither : Validated e a -> Either e a
toEither = validated Left Right

--------------------------------------------------------------------------------
--          Interfaces
--------------------------------------------------------------------------------

public export
Eq e => Eq a => Eq (Validated e a) where
  Invalid x == Invalid y = x == y
  Valid x   == Valid y   = x == y
  _         == _         = False

public export
Ord e => Ord a => Ord (Validated e a) where
  compare (Invalid x) (Invalid y) = compare x y
  compare (Invalid _) (Valid _)   = LT
  compare (Valid _)   (Invalid _) = GT
  compare (Valid x)   (Valid y)   = compare x y

public export
Show e => Show a => Show (Validated e a) where
  showPrec p (Invalid e) = showCon p "Invalid" (showArg e)
  showPrec p (Valid a)   = showCon p "Valid" (showArg a)

public export
Functor (Validated e) where
  map _ (Invalid err) = Invalid err
  map f (Valid val)   = Valid $ f val

public export
Semigroup e => Applicative (Validated e) where
  pure = Valid
  Valid   f  <*> Valid v    = Valid $ f v
  Valid   _  <*> Invalid ve = Invalid ve
  Invalid e1 <*> Invalid e2 = Invalid $ e1 <+> e2
  Invalid ve <*> Valid _    = Invalid ve

public export
Foldable (Validated e) where
  foldr acc st (Invalid _) = st
  foldr acc st (Valid v)   = acc v st

  foldl acc st (Invalid _) = st
  foldl acc st (Valid v)   = acc st v

  foldlM acc st (Invalid _) = pure st
  foldlM acc st (Valid v)   = acc st v

  foldMap f (Invalid _) = neutral
  foldMap f (Valid v)   = f v

  toList (Invalid _) = []
  toList (Valid v)   = [v]

  null (Invalid _) = True
  null (Valid v)   = False

public export
Traversable (Validated e) where
  traverse f (Invalid ve) = pure $ Invalid ve
  traverse f (Valid va)   = Valid <$> f va

public export
Bifunctor Validated where
  bimap f g (Invalid ve) = Invalid $ f ve
  bimap f g (Valid va)   = Valid $ g va

  mapFst f (Invalid ve) = Invalid $ f ve
  mapFst f (Valid va)   = Valid va

  mapSnd f (Invalid ve) = Invalid ve
  mapSnd f (Valid va)   = Valid $ f va

public export
Bifoldable Validated where
  bifoldr f g st (Invalid ve) = f ve st
  bifoldr f g st (Valid va)   = g va st

  bifoldl f g st (Invalid ve) = f st ve
  bifoldl f g st (Valid va)   = g st va

  binull _ = False

public export
Bitraversable Validated where
  bitraverse f g (Invalid ve) = Invalid <$> f ve
  bitraverse f g (Valid va)   = Valid <$> g va

public export
Monoid e => Alternative (Validated e) where
  empty = Invalid neutral

  Valid va  <|> _         = Valid va
  Invalid x <|> Invalid y = Invalid $ x <+> y
  Invalid _ <|> Valid va  = Valid va
