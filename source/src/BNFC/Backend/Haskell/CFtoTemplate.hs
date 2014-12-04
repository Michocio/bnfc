{-
    BNF Converter: Template Generator
    Copyright (C) 2004  Author:  Markus Forberg

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
-}


module BNFC.Backend.Haskell.CFtoTemplate (
		    cf2Template
                    ) where

import BNFC.Backend.Haskell.Utils (hsReservedWords, catvars)
import BNFC.CF
import BNFC.Utils ((+++))
import Data.Char
import BNFC.PrettyPrint

type ModuleName = String

cf2Template :: ModuleName -> ModuleName -> ModuleName -> Bool -> CF -> String
cf2Template skelName absName errName functor cf = unlines
    [ "module "++ skelName ++ " where\n"
    , "-- Haskell module generated by the BNF converter\n"
    , "import " ++ absName
    , "import " ++ errName
    , "type Result = Err String\n"
    , "failure :: Show a => a -> Result"
    , "failure x = Bad $ \"Undefined case: \" ++ show x\n"
    , unlines $ map (render . \(s,xs) -> case_fun functor s xs) $ specialData cf ++ cf2data cf
    ]

{- ----
cf2Template :: ModuleName -> CF -> String
cf2Template name cf = unlines
  [
  "module Skel"++ name ++ " where\n",
  "-- Haskell module generated by the BNF converter\n",
  "import Abs" ++ name,
  "import ErrM",
  "type Result = Err String\n",
  "failure :: Show a => a -> Result",
  "failure x = Bad $ \"Undefined case: \" ++ show x\n",
  unlines $ map (\(s,xs) -> case_fun s (toArgs xs)) $ specialData cf ++ cf2data cf
  ]
 where toArgs               [] = []
       toArgs ((cons,args):xs)
	   = (cons ++ " " ++  names False (map (checkRes . var) args) (1 :: Int)) : toArgs xs
       names _ [] _ = []
       names b (x:xs) n
        | elem x xs = (x ++ show n) ++ " " ++ names True xs (n+1)
	| otherwise = (x ++ if b then show n else "") ++ " " ++ names b xs (if b then n+1 else n)
       var ('[':xs)  = var (init xs) ++ "s"
       var "Ident"   = "id"
       var "Integer" = "n"
       var "String"  = "str"
       var "Char"    = "c"
       var "Double"  = "d"
       var xs        = map toLower xs
       checkRes s
        | elem s reservedHaskell = s ++ "'"
	| otherwise              = s
       reservedHaskell = ["case","class","data","default","deriving","do","else","if",
			  "import","in","infix","infixl","infixr","instance","let","module",
			  "newtype","of","then","type","where","as","qualified","hiding"]
-}

-- |
-- >>> case_fun False (Cat "Expr") [("EInt", [TokenCat "Integer"]), ("EAdd", [Cat "Expr", Cat "Expr"])]
-- transExpr :: Expr -> Result
-- transExpr x = case x of
--   EInt integer -> failure x
--   EAdd expr1 expr2 -> failure x
--
-- >>> case_fun True (Cat "Expr") [("EInt", [TokenCat "Integer"]), ("EAdd", [Cat "Expr", Cat "Expr"])]
-- transExpr :: Show a => Expr a -> Result
-- transExpr x = case x of
--   EInt _ integer -> failure x
--   EAdd _ expr1 expr2 -> failure x
--
-- TokenCat are not generated as functors:
-- >>> case_fun True (TokenCat "MyIdent") [("MyIdent", [TokenCat "String"])]
-- transMyIdent :: MyIdent -> Result
-- transMyIdent x = case x of
--   MyIdent string -> failure x
case_fun :: Bool -> Cat -> [(Fun,[Cat])] -> Doc
case_fun functor' cat xs = vcat
    [ fname <+> "::" <+> iffunctor "Show a =>" <+> type_ <+> "-> Result"
    , fname <+> "x = case x of"
    , nest 2 $ vcat (map mkOne xs)
    ]
  where
    -- If the functor option is set AND the category is not a token type,
    -- then the type is a functor.
    iffunctor doc | functor' && not (isTokenCat cat) = doc
                  | otherwise = empty
    type_ = cat' <+> iffunctor "a"
    fname = "trans" <> cat'
    cat' =  text (show cat)
    mkOne (cons, args) =
        let ns = catvars args -- names False (map (checkRes .var) args) 1
        in  text cons <+> iffunctor "_" <+> hsep ns <+> "-> failure x"
    names _ [] _ = []
    names b (x:xs) n
      | x `elem` xs = (x ++ show n) ++ " " ++ names True xs (n+1)
      | otherwise = (x ++ if b then show n else "") ++ " " ++ names b xs (if b then n+1 else n)
    var (ListCat c) = var c ++ "s"
    var xs        = map toLower (show xs)
    checkRes s
      | s `elem` hsReservedWords = s ++ "'"
      | otherwise              = s
