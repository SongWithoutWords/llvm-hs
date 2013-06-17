module LLVM.General.Test.Metadata where

import Test.Framework
import Test.Framework.Providers.HUnit
import Test.HUnit

import LLVM.General.Test.Support

import LLVM.General.AST as A
import qualified LLVM.General.AST.Linkage as L
import qualified LLVM.General.AST.Visibility as V
import qualified LLVM.General.AST.CallingConvention as CC
import qualified LLVM.General.AST.Constant as C
import LLVM.General.AST.Global as G

tests = testGroup "Metadata" [
  testCase "local" $ do
    let ast = Module "<string>" Nothing Nothing [
         GlobalDefinition $ globalVariableDefaults { G.name = UnName 0, G.type' = IntegerType 32 },
         GlobalDefinition $ Function L.External V.Default CC.C [] (IntegerType 32) (Name "foo") ([
            ],False)
          [] 
          Nothing 0         
          [
           BasicBlock (UnName 0) [
              UnName 1 := Load {
                         volatile = False,
                         address = ConstantOperand (C.GlobalReference (UnName 0)),
                         maybeAtomicity = Nothing,
                         A.alignment = 0,
                         metadata = []
                       }
              ] (
              Do $ Ret (Just (ConstantOperand (C.Int (IntegerType 32) 0))) [
                (
                  "my-metadatum", 
                  MetadataNode [
                   LocalReference (UnName 1),
                   MetadataStringOperand "super hyper"
                  ]
                )
              ]
            )
          ]
         ]
    let s = "; ModuleID = '<string>'\n\
            \\n\
            \@0 = external global i32\n\
            \\n\
            \define i32 @foo() {\n\
            \  %1 = load i32* @0\n\
            \  ret i32 0, !my-metadatum !{i32 %1, metadata !\"super hyper\"}\n\
            \}\n"
    strCheck ast s,

  testCase "global" $ do
    let ast = Module "<string>" Nothing Nothing [
         GlobalDefinition $ Function L.External V.Default CC.C [] (IntegerType 32) (Name "foo") ([
            ],False)
          [] 
          Nothing 0         
          [
           BasicBlock (UnName 0) [
              ] (
              Do $ Ret (Just (ConstantOperand (C.Int (IntegerType 32) 0))) [
                ("my-metadatum", MetadataNodeReference (MetadataNodeID 0))
              ]
            )
          ],
          MetadataNodeDefinition (MetadataNodeID 0) [ ConstantOperand (C.Int (IntegerType 32) 1) ]
         ]
    let s = "; ModuleID = '<string>'\n\
            \\n\
            \define i32 @foo() {\n\
            \  ret i32 0, !my-metadatum !0\n\
            \}\n\
            \\n\
            \!0 = metadata !{i32 1}\n"
    strCheck ast s,

  testCase "named" $ do
    let ast = Module "<string>" Nothing Nothing [
          NamedMetadataDefinition "my-module-metadata" [MetadataNodeID 0],
          MetadataNodeDefinition (MetadataNodeID 0) [ ConstantOperand (C.Int (IntegerType 32) 1) ]
         ]
    let s = "; ModuleID = '<string>'\n\
            \\n\
            \!my-module-metadata = !{!0}\n\
            \\n\
            \!0 = metadata !{i32 1}\n"
    strCheck ast s,

  testGroup "cyclic" [
    testCase "metadata-only" $ do
      let ast = Module "<string>" Nothing Nothing [
            NamedMetadataDefinition "my-module-metadata" [MetadataNodeID 0],
            MetadataNodeDefinition (MetadataNodeID 0) [
              MetadataNodeOperand (MetadataNodeReference (MetadataNodeID 1)) 
             ],
            MetadataNodeDefinition (MetadataNodeID 1) [
              MetadataNodeOperand (MetadataNodeReference (MetadataNodeID 0)) 
             ]
           ]
      let s = "; ModuleID = '<string>'\n\
              \\n\
              \!my-module-metadata = !{!0}\n\
              \\n\
              \!0 = metadata !{metadata !1}\n\
              \!1 = metadata !{metadata !0}\n"
      strCheck ast s,

    testCase "metadata-global" $ do
      let ast = Module "<string>" Nothing Nothing [
           GlobalDefinition $ Function L.External V.Default CC.C [] VoidType (Name "foo") ([
              ],False)
            [] 
            Nothing 0         
            [
             BasicBlock (UnName 0) [
              ] (
                Do $ Ret Nothing [ ("my-metadatum", MetadataNodeReference (MetadataNodeID 0)) ]
              )
            ],
            MetadataNodeDefinition (MetadataNodeID 0) [
              ConstantOperand (C.GlobalReference (Name "foo"))
             ]
           ]
      let s = "; ModuleID = '<string>'\n\
              \\n\
              \define void @foo() {\n\
              \  ret void, !my-metadatum !0\n\
              \}\n\
              \\n\
              \!0 = metadata !{void ()* @foo}\n"
      strCheck ast s
   ]

 ]