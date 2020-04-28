{-# LANGUAGE CPP #-}
#if __GLASGOW_HASKELL__ <= 708
{-# LANGUAGE OverlappingInstances #-}
#endif
{-# LANGUAGE FlexibleInstances #-}
{-# OPTIONS_GHC -fno-warn-incomplete-patterns #-}

-- | Pretty-printer for PrintGramatyka.
--   Generated by the BNF converter.

module PrintGramatyka where

import qualified AbsGramatyka
import Data.Char

-- | The top-level printing method.

printTree :: Print a => a -> String
printTree = render . prt 0

type Doc = [ShowS] -> [ShowS]

doc :: ShowS -> Doc
doc = (:)

render :: Doc -> String
render d = rend 0 (map ($ "") $ d []) "" where
  rend i ss = case ss of
    "["      :ts -> showChar '[' . rend i ts
    "("      :ts -> showChar '(' . rend i ts
    "{"      :ts -> showChar '{' . new (i+1) . rend (i+1) ts
    "}" : ";":ts -> new (i-1) . space "}" . showChar ';' . new (i-1) . rend (i-1) ts
    "}"      :ts -> new (i-1) . showChar '}' . new (i-1) . rend (i-1) ts
    ";"      :ts -> showChar ';' . new i . rend i ts
    t  : ts@(p:_) | closingOrPunctuation p -> showString t . rend i ts
    t        :ts -> space t . rend i ts
    _            -> id
  new i   = showChar '\n' . replicateS (2*i) (showChar ' ') . dropWhile isSpace
  space t = showString t . (\s -> if null s then "" else ' ':s)

  closingOrPunctuation :: String -> Bool
  closingOrPunctuation [c] = c `elem` closerOrPunct
  closingOrPunctuation _   = False

  closerOrPunct :: String
  closerOrPunct = ")],;"

parenth :: Doc -> Doc
parenth ss = doc (showChar '(') . ss . doc (showChar ')')

concatS :: [ShowS] -> ShowS
concatS = foldr (.) id

concatD :: [Doc] -> Doc
concatD = foldr (.) id

replicateS :: Int -> ShowS -> ShowS
replicateS n f = concatS (replicate n f)

-- | The printer class does the job.

class Print a where
  prt :: Int -> a -> Doc
  prtList :: Int -> [a] -> Doc
  prtList i = concatD . map (prt i)

instance {-# OVERLAPPABLE #-} Print a => Print [a] where
  prt = prtList

instance Print Char where
  prt _ s = doc (showChar '\'' . mkEsc '\'' s . showChar '\'')
  prtList _ s = doc (showChar '"' . concatS (map (mkEsc '"') s) . showChar '"')

mkEsc :: Char -> Char -> ShowS
mkEsc q s = case s of
  _ | s == q -> showChar '\\' . showChar s
  '\\'-> showString "\\\\"
  '\n' -> showString "\\n"
  '\t' -> showString "\\t"
  _ -> showChar s

prPrec :: Int -> Int -> Doc -> Doc
prPrec i j = if j < i then parenth else id

instance Print Integer where
  prt _ x = doc (shows x)

instance Print Double where
  prt _ x = doc (shows x)

instance Print AbsGramatyka.Ident where
  prt _ (AbsGramatyka.Ident i) = doc (showString i)

instance Print AbsGramatyka.Program where
  prt i e = case e of
    AbsGramatyka.Program topdefs -> prPrec i 0 (concatD [prt 0 topdefs])

instance Print AbsGramatyka.TopDef where
  prt i e = case e of
    AbsGramatyka.FnDef id args block -> prPrec i 0 (concatD [doc (showString "def"), prt 0 id, doc (showString "("), prt 0 args, doc (showString ")"), prt 0 block])
  prtList _ [x] = concatD [prt 0 x]
  prtList _ (x:xs) = concatD [prt 0 x, prt 0 xs]

instance Print [AbsGramatyka.TopDef] where
  prt = prtList

instance Print AbsGramatyka.Arg where
  prt i e = case e of
    AbsGramatyka.Arg id -> prPrec i 0 (concatD [prt 0 id])
    AbsGramatyka.CntsArg id -> prPrec i 0 (concatD [doc (showString "const"), prt 0 id])
  prtList _ [] = concatD []
  prtList _ [x] = concatD [prt 0 x]
  prtList _ (x:xs) = concatD [prt 0 x, doc (showString ","), prt 0 xs]

instance Print [AbsGramatyka.Arg] where
  prt = prtList

instance Print AbsGramatyka.Block where
  prt i e = case e of
    AbsGramatyka.Block stmts -> prPrec i 0 (concatD [doc (showString "{"), prt 0 stmts, doc (showString "}")])

instance Print [AbsGramatyka.Stmt] where
  prt = prtList

instance Print AbsGramatyka.Stmt where
  prt i e = case e of
    AbsGramatyka.Empty -> prPrec i 0 (concatD [doc (showString ";")])
    AbsGramatyka.BStmt block -> prPrec i 0 (concatD [prt 0 block])
    AbsGramatyka.DeclCon id expr -> prPrec i 0 (concatD [doc (showString "const"), prt 0 id, doc (showString "="), prt 0 expr])
    AbsGramatyka.DeclFun id args block -> prPrec i 0 (concatD [doc (showString "def"), prt 0 id, doc (showString "("), prt 0 args, doc (showString ")"), prt 0 block])
    AbsGramatyka.Ass id expr -> prPrec i 0 (concatD [prt 0 id, doc (showString "="), prt 0 expr, doc (showString ";")])
    AbsGramatyka.TupleAss id exprs -> prPrec i 0 (concatD [prt 0 id, doc (showString "="), doc (showString "("), prt 0 exprs, doc (showString ")"), doc (showString ";")])
    AbsGramatyka.TupleAss1 args exprs -> prPrec i 0 (concatD [doc (showString "("), prt 0 args, doc (showString ")"), doc (showString "="), doc (showString "("), prt 0 exprs, doc (showString ")"), doc (showString ";")])
    AbsGramatyka.TupleAss2 args expr -> prPrec i 0 (concatD [doc (showString "("), prt 0 args, doc (showString ")"), doc (showString "="), prt 0 expr, doc (showString ";")])
    AbsGramatyka.Incr id -> prPrec i 0 (concatD [prt 0 id, doc (showString "++"), doc (showString ";")])
    AbsGramatyka.Decr id -> prPrec i 0 (concatD [prt 0 id, doc (showString "--"), doc (showString ";")])
    AbsGramatyka.Ret expr -> prPrec i 0 (concatD [doc (showString "return"), prt 0 expr, doc (showString ";")])
    AbsGramatyka.RetTuple exprs -> prPrec i 0 (concatD [doc (showString "return"), doc (showString "("), prt 0 exprs, doc (showString ")"), doc (showString ";")])
    AbsGramatyka.VRet -> prPrec i 0 (concatD [doc (showString "return"), doc (showString ";")])
    AbsGramatyka.Cond expr stmt -> prPrec i 0 (concatD [doc (showString "if"), doc (showString "("), prt 0 expr, doc (showString ")"), prt 0 stmt])
    AbsGramatyka.CondElse expr stmt1 stmt2 -> prPrec i 0 (concatD [doc (showString "if"), doc (showString "("), prt 0 expr, doc (showString ")"), prt 0 stmt1, doc (showString "else"), prt 0 stmt2])
    AbsGramatyka.While expr stmt -> prPrec i 0 (concatD [doc (showString "while"), doc (showString "("), prt 0 expr, doc (showString ")"), prt 0 stmt])
    AbsGramatyka.For id expr1 expr2 stmt -> prPrec i 0 (concatD [doc (showString "for"), doc (showString "("), prt 0 id, doc (showString "="), prt 0 expr1, doc (showString "to"), prt 0 expr2, doc (showString ")"), prt 0 stmt])
    AbsGramatyka.ForIn id1 id2 stmt -> prPrec i 0 (concatD [doc (showString "for"), doc (showString "("), prt 0 id1, doc (showString "in"), prt 0 id2, doc (showString ")"), prt 0 stmt])
    AbsGramatyka.Break -> prPrec i 0 (concatD [doc (showString "break")])
    AbsGramatyka.Conti -> prPrec i 0 (concatD [doc (showString "continue")])
    AbsGramatyka.SExp expr -> prPrec i 0 (concatD [prt 0 expr, doc (showString ";")])
    AbsGramatyka.PrInt expr -> prPrec i 0 (concatD [doc (showString "printInt"), doc (showString "("), prt 0 expr, doc (showString ")")])
    AbsGramatyka.PrStr expr -> prPrec i 0 (concatD [doc (showString "printStr"), doc (showString "("), prt 0 expr, doc (showString ")")])
    AbsGramatyka.Honk expr -> prPrec i 0 (concatD [doc (showString "honk"), doc (showString "("), prt 0 expr, doc (showString ")")])
    AbsGramatyka.Error -> prPrec i 0 (concatD [doc (showString "error"), doc (showString "("), doc (showString ")")])
  prtList _ [] = concatD []
  prtList _ (x:xs) = concatD [prt 0 x, prt 0 xs]

instance Print AbsGramatyka.Expr where
  prt i e = case e of
    AbsGramatyka.EVar id -> prPrec i 7 (concatD [prt 0 id])
    AbsGramatyka.ELitInt n -> prPrec i 7 (concatD [prt 0 n])
    AbsGramatyka.ELitTrue -> prPrec i 7 (concatD [doc (showString "true")])
    AbsGramatyka.ELitFalse -> prPrec i 7 (concatD [doc (showString "false")])
    AbsGramatyka.EApp id exprs -> prPrec i 7 (concatD [prt 0 id, doc (showString "("), prt 0 exprs, doc (showString ")")])
    AbsGramatyka.EString str -> prPrec i 7 (concatD [prt 0 str])
    AbsGramatyka.EList exprs -> prPrec i 7 (concatD [doc (showString "["), prt 0 exprs, doc (showString "]")])
    AbsGramatyka.EList1 expr1 expr2 -> prPrec i 7 (concatD [doc (showString "["), prt 0 expr1, doc (showString "]"), doc (showString "*"), prt 0 expr2])
    AbsGramatyka.EAt id expr -> prPrec i 7 (concatD [prt 0 id, doc (showString "["), prt 0 expr, doc (showString "]")])
    AbsGramatyka.Neg expr -> prPrec i 6 (concatD [doc (showString "-"), prt 7 expr])
    AbsGramatyka.Not expr -> prPrec i 6 (concatD [doc (showString "!"), prt 7 expr])
    AbsGramatyka.EMul expr1 mulop expr2 -> prPrec i 5 (concatD [prt 5 expr1, prt 0 mulop, prt 6 expr2])
    AbsGramatyka.EAdd expr1 addop expr2 -> prPrec i 4 (concatD [prt 4 expr1, prt 0 addop, prt 5 expr2])
    AbsGramatyka.ERel expr1 relop expr2 -> prPrec i 3 (concatD [prt 3 expr1, prt 0 relop, prt 4 expr2])
    AbsGramatyka.EAnd expr1 expr2 -> prPrec i 2 (concatD [prt 3 expr1, doc (showString "&&"), prt 2 expr2])
    AbsGramatyka.EOr expr1 expr2 -> prPrec i 1 (concatD [prt 2 expr1, doc (showString "||"), prt 1 expr2])
    AbsGramatyka.ELambda args block -> prPrec i 0 (concatD [doc (showString "\\"), prt 0 args, doc (showString "->"), prt 0 block])
    AbsGramatyka.ELambdaS args block -> prPrec i 0 (concatD [doc (showString "lambda"), prt 0 args, doc (showString "->"), prt 0 block])
  prtList _ [] = concatD []
  prtList _ [x] = concatD [prt 0 x]
  prtList _ (x:xs) = concatD [prt 0 x, doc (showString ","), prt 0 xs]

instance Print [AbsGramatyka.Expr] where
  prt = prtList

instance Print AbsGramatyka.AddOp where
  prt i e = case e of
    AbsGramatyka.Plus -> prPrec i 0 (concatD [doc (showString "+")])
    AbsGramatyka.Minus -> prPrec i 0 (concatD [doc (showString "-")])

instance Print AbsGramatyka.MulOp where
  prt i e = case e of
    AbsGramatyka.Times -> prPrec i 0 (concatD [doc (showString "*")])
    AbsGramatyka.Div -> prPrec i 0 (concatD [doc (showString "/")])
    AbsGramatyka.Mod -> prPrec i 0 (concatD [doc (showString "%")])

instance Print AbsGramatyka.RelOp where
  prt i e = case e of
    AbsGramatyka.LTH -> prPrec i 0 (concatD [doc (showString "<")])
    AbsGramatyka.LE -> prPrec i 0 (concatD [doc (showString "<=")])
    AbsGramatyka.GTH -> prPrec i 0 (concatD [doc (showString ">")])
    AbsGramatyka.GE -> prPrec i 0 (concatD [doc (showString ">=")])
    AbsGramatyka.EQU -> prPrec i 0 (concatD [doc (showString "==")])
    AbsGramatyka.NE -> prPrec i 0 (concatD [doc (showString "!=")])

