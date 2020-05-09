module SkelGrammar where

import Control.Monad.Reader
import Control.Monad.State
import Control.Monad.Except
import Control.Monad.IO.Class
import Data.Map
import Data.String

import qualified Data.Set as Set
import AbsGrammar
import ErrM

type Fun = [Value] -> Interpreter Value
type Location = Integer
data Value = Int Integer
  | Bool Bool 
  | String String
  | Fun Fun
  | Array [Value]
  | Tuple [Value]
data Mode = NothingMode
  | ReturnMode
  | ContinueMode
  | BreakMode
  deriving (Show, Eq)

type Store = Map Location Value
type Env = Map Ident (Location, Bool)

type Context = (Env, Mode, Maybe Value)

type Result = ExceptT String IO

type Interpreter a = StateT Store (ReaderT Context Result) a

-- + 08 (zmienne read-only i pętla for)

showVal :: Value -> String
showVal (Int i) = "Int:" ++ show i
showVal (Bool b) 
  | b = "Bool: true"
  | otherwise = "Boool: false"
showVal (String s) = "String: '" ++ s ++ "'"
showVal (Fun f) = "Function"
showVal (Array arr) = "Array: " ++ "[" ++ Prelude.foldr (\x b-> showVal x ++ "," ++ b) "]" arr
showVal (Tuple tpl) = "Tuple:"  ++ "(" ++ Prelude.foldr (\x b-> showVal x ++ "," ++ b) ")" tpl

checkMode :: Mode -> Mode -> Interpreter ()
checkMode mode expected =
  if mode == expected then
    return ()
  else
    throwError $ "Invalid Mode: Expected " ++ show expected ++ ", got " ++ show mode 

interpret :: Program -> (Result ())
interpret p = do
  runReaderT (execStateT (transProgram p) empty) (empty, NothingMode, Nothing)
  return ()


transProgram :: Program -> Interpreter ()
transProgram (Program ds) = do
  context <- transTopDefs ds
  main <- local (const context) $ getFun (Ident "main")
  local (const context) $ main []
  return ()


transTopDefs :: [TopDef] -> Interpreter Context
transTopDefs [] = ask
transTopDefs (d:ds) = do
  context <- transTopDef d
  newCont <- local (const context) $ transTopDefs ds
  return newCont

transTopDef :: TopDef -> Interpreter Context
transTopDef (FnDef funName args block) = createAndSetFun funName args block

createAndSetFun :: Ident -> [Arg] -> Block -> Interpreter Context
createAndSetFun funName args block = do
  context <- ask
  let newFun values = do
      newCont1 <- local (const context) $ transArguments args values-- params
      newCont2 <- setFun funName newFun newCont1 -- recursion
      (_, mode, mVal) <- local (const newCont2) $ transBlock block
      case mVal of
        Just val -> return $ val
        Nothing ->  return $ Int $ 0
  newCont <-setFun funName newFun context
  return $ newCont


createLambda :: Context -> [Arg] -> Block -> Fun
createLambda context args block values = do
  newCont <- local (const context) $ transArguments args values-- params
  -- newCont2 <- setFun funName newFun newCont1 -- recursion
  (_, mode, mVal) <- local (const newCont) $ transBlock block
  case mVal of
    Just val -> return $ val
    Nothing ->  return $ Int $ 0

getFun :: Ident -> Interpreter Fun
getFun funName = do
  val <- transExpr (EVar funName)
  case val of
    (Fun f) -> return f
    otherwise -> throwError $ "Error: expected Fun got: " ++ showVal val

setFun :: Ident -> Fun -> Context -> Interpreter Context
setFun ident fun context = local (const context) $ assignValue ident (Fun fun) False False
  -- newLoc <- next
  -- let loc = if member ident env then env ! ident else newLoc
  -- modify (\store -> insert loc (Fun fun) store)
  -- let newEnv = insert ident loc env
  -- return $ (newEnv, mode, mVal)

runFun :: Ident -> [Expr] -> Interpreter Value
runFun ident exprs = do
  context <- ask
  fun <- local (const context) $ getFun ident
  args <- mapM transExpr exprs
  value <- local (const context) $ fun args
  return value

assignValue :: Ident -> Value -> Bool -> Bool -> Interpreter Context
assignValue ident val const argType =  do
  (env, mode, mVal) <- ask
  if not argType && member ident env && (snd $ env ! ident) then
    throwError $ "Error: " ++ show ident ++ " is a const type."
  else do
    newLoc <- next
    let loc = if not argType && member ident env then fst $ env ! ident else newLoc
    modify (\store -> insert loc val store)
    let newEnv = insert ident (loc, const) env
    return (newEnv, mode, mVal)

next :: Interpreter Location
next = do
  store <- get
  let loc = if size store /= 0 then (fst $ findMax store) + 1 else 1
  put store
  return loc


transArguments :: [Arg] -> [Value]-> Interpreter Context
transArguments [] [] = ask
transArguments [] _ = throwError $ "Error: Too many arguments"
transArguments _ [] = throwError $ "Error: Not enough arguments"
transArguments (var:vars) (val:vals) = do
  newCont1 <- transArgument var val
  newCont2 <- local (const newCont1) $ transArguments vars vals -- todo co robi to const?
  return newCont2

transArgument :: Arg -> Value-> Interpreter Context
transArgument var val = case var of
  Arg ident -> assignValue ident val False True
  CntsArg ident -> assignValue ident val True True
 
transBlock :: Block -> Interpreter Context
transBlock (Block (stmt:stmts)) = do
  (env, mode, mVal) <- ask
  case (mode, stmt) of
    (NothingMode, _) -> do 
      newCont1 <- transStmt stmt
      newCont2 <- local (const newCont1) (transBlock (Block stmts))
      return newCont2
    (ContinueMode, While _ _) -> do 
      newCont1 <- transStmt stmt
      newCont2 <- local (const newCont1) (transBlock (Block stmts))
      return newCont2
    (BreakMode, While _ _) -> do 
      newCont1 <- transStmt stmt
      newCont2 <- local (const newCont1) (transBlock (Block stmts))
      return newCont2
    (otherwise, _) -> return (env, mode, mVal)

transBlock (Block []) = do
  context <- ask
  return $ context 

identToArg :: Ident -> Arg
identToArg k = Arg k
   
transStmt :: Stmt -> Interpreter Context
transStmt x = case x of
  Empty -> do
    context <- ask
    return context

  BStmt block -> transBlock block

  DeclFun ident args block -> createAndSetFun ident args block

  Ass ident expr -> do
    val <- transExpr expr
    newCont <- assignValue ident val False False
    return newCont
  
  DeclCon ident expr ->  do
    val <- transExpr expr
    newCont <- assignValue ident val True False
    return newCont
  
  TupleAss idents expr -> do
    val <- transExpr expr
    case val of
      Tuple arr -> transArguments     (Prelude.map identToArg idents) arr
      otherwise -> throwError $ "Error: expected Tuple got: " ++ showVal val

  Incr ident -> transStmt $ Ass ident (EAdd (EVar ident) Plus (ELitInt 1))
  
  Decr ident -> transStmt $ Ass ident (EAdd (EVar ident) Minus (ELitInt 1))
  
  Ret expr -> do
    (env, mode, _) <- ask
    checkMode mode NothingMode
    val <- transExpr expr
    return (env, ReturnMode, Just val)

  VRet -> transStmt $ Ret (ELitInt 0)
  
  Cond expr stmt -> transStmt (CondElse expr stmt Empty)
  
  CondElse expr stmt1 stmt2 -> do
    val <- transExpr expr
    case val of
      (Bool True) -> transStmt stmt1
      (Bool False) -> transStmt stmt2 
      otherwise -> throwError $ "Error: in If conditions expected Bool got: " ++ showVal val

  While expr stmt -> do
    (env, mode, mVal) <- ask
    val <- transExpr expr
    case (mode, val) of
      (BreakMode, _) -> return (env, NothingMode, mVal)
      (ContinueMode, Bool True) -> local (const (env, NothingMode, mVal)) $ transBlock (Block [stmt, While expr stmt])
      (ContinueMode, Bool False) -> return (env, NothingMode, mVal)  
      (NothingMode, Bool True) -> transBlock (Block [stmt, While expr stmt])
      (_, Bool _) -> return (env, mode, mVal) 
      otherwise -> throwError $ "Error: in While conditions expected Bool got: " ++ showVal val
  
  For ident expr1 expr2 stmt -> transBlock (Block [Ass ident expr1, Incr ident, While (ERel (EVar ident) LTH expr2) (BStmt $ Block [stmt, Incr ident])])

  Break -> do
    (env, mode, mVal) <- ask
    case mode of
      NothingMode -> return (env, BreakMode, mVal)
      otherwise -> return (env, mode, mVal)

  Conti -> do
    (env, mode, mVal) <- ask
    case mode of
      NothingMode -> return (env, ContinueMode, mVal)
      otherwise -> return (env, mode, mVal)

  SExp expr -> do
    context <- ask
    _ <- transExpr expr
    return context
  
  Print expr -> do
    val <- transExpr expr
    lift $ lift $  lift $ putStrLn $ showVal val
    context <- ask
    return context
  
  Honk expr -> do
    val <- transExpr expr
    context <- transStmt $ Print (EString $ "Honk: " ++ showVal val)
    return context

  Error -> throwError $ "Error from error()"

transExprHlp :: Expr -> Expr -> (Value -> Value-> Interpreter Value) -> Interpreter Value
transExprHlp expr1 expr2 op = do
  val1 <- transExpr expr1
  val2 <- transExpr expr2 
  result <- op val1 val2
  return result

transExpr :: Expr -> Interpreter Value
transExpr x = case x of
  EVar ident -> do 
    store <- get
    (env, _, _) <- ask
    if not (member ident env) then
      throwError $ "Variable not initialized: " ++ show ident
    else
      return $ store ! (fst $ env ! ident)

  ELitInt integer -> return $ Int $ integer
  
  ELitTrue -> return $ Bool $ True
  
  ELitFalse ->  return $ Bool $ False
  
  EApp ident exprs -> runFun ident exprs
  
  EString string -> return $ String $ string

  EList exprs -> do
    values <- mapM transExpr exprs
    return $ Array $ values

  EList1 expr1 expr2 -> do
    val1 <- transExpr expr1
    val2 <- transExpr expr2
    case (val2) of
      (Int x) -> return $ Array (Prelude.take (fromIntegral x) (repeat val1))
      otherwise -> throwError $ "Error: expected Int got: " ++ showVal val2

  ETuple exprs -> do
    values <- mapM transExpr exprs
    return $ Tuple $ values

  EAt ident expr -> do
    val <- transExpr expr
    var <- transExpr (EVar ident)
    case (var, val) of
      (Array arr, Int i) -> if (fromIntegral i) < (length arr) then 
          return $ arr !! (fromIntegral i)
        else 
          throwError $ "Error: index out of range" 
      (Tuple values, Int i) -> if (fromIntegral i) < (length values) then 
          return $ values !! (fromIntegral i)
        else 
          throwError $ "Error:index out of range"
      (Array _, _) ->  throwError $ "Error: expected Int got: " ++ showVal val
      (Tuple _, _) ->  throwError $ "Error: expected Int got: " ++ showVal val
      otherwise -> throwError $ "Invalid variable"

  EMul expr1 mulop expr2 -> transExprHlp expr1 expr2 (transMulOp mulop)
  EAdd expr1 addop expr2 -> transExprHlp expr1 expr2 (transAddOp addop)
  ERel expr1 relop expr2 -> transExprHlp expr1 expr2 (transRelOp relop)

  Neg expr -> do
    val <- transExpr expr
    case val of
      Int i -> return $ Int $ ( -i)
      oherwise -> throwError $ "Incorrect Negation operation type: " ++ showVal val
  Not expr -> do
    val <- transExpr expr
    case val of
      Bool b -> return $ Bool $ (not b)
      otherwise -> throwError $ "Incorrect Not operation type: " ++ showVal val

  EAnd expr1 expr2 -> do
    val1 <- transExpr expr1
    case val1 of
      Bool b1 -> if b1
        then do -- todo jakby sie walilo to zmienic
          val2 <- transExpr expr2
          case val2 of
            Bool b1 -> return $ Bool $ b1
            otherwise -> throwError $ "Incorrect And operation type: " ++ showVal val2
        else
          return $ Bool $ False
      otherwise -> throwError $ "Incorrect And operation type: " ++ showVal val1

  EOr expr1 expr2 -> do
    val1 <- transExpr expr1
    case val1 of
      Bool b1 -> if not b1
        then do
          val2 <- transExpr expr2
          case val2 of
            Bool b1 -> return $ Bool $ b1
            otherwise -> throwError $ "Incorrect Or operation type: " ++ showVal val2
        else
          return $ Bool $ False
      otherwise -> throwError $ "Incorrect Or operation type: " ++ showVal val1

  ELambda args block -> do
    context <- ask 
    let newFun = createLambda context args block
    return  $ (Fun newFun)

  ELambdaS args block -> transExpr $ ELambda args block

transAddOp :: AddOp -> Value -> Value -> Interpreter Value
transAddOp x (Int l) (Int r) = case x of
  Plus -> return $ Int $ l + r
  Minus -> return $ Int $ l - r
transAddOp Plus (String l) (String r) = return $ String $ l ++ r
transAddOp _ l r = do
   throwError $ "Incorrect Plus/Minus operation types: " ++ showVal l ++ " " ++ showVal r

transMulOp :: MulOp -> Value -> Value -> Interpreter Value
transMulOp x (Int l) (Int r) = case x of
  Times -> return $ Int $ l * r
  Div -> do
    if r /= 0 then
      return $ Int $ div l r
    else
      throwError $ "Invalid operation: division by zero"
  Mod -> do
    if r > 0 then
      return $ Int $ mod l r
    else
      throwError $ "Invalid operation: modulo 0"
transMulOp _ l r = do
  throwError $ "Incorrect Times/Div/Mod operation types: " ++ showVal l ++ " " ++ showVal r

transRelOp :: RelOp -> Value -> Value -> Interpreter Value
transRelOp x (Int l) (Int r) = case x of
  LTH -> return $ Bool $ l < r
  LE -> return $ Bool $ l <= r
  GTH -> return $ Bool $ l > r
  GE -> return $ Bool $ l >= r
  EQU -> return $ Bool $ l == r
  NE -> return $ Bool $ l /= r
transRelOp _ l r = throwError $ "Incorrect comparison operation types: " ++ showVal l ++ " " ++ showVal r

