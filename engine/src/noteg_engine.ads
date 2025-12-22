-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-FileCopyrightText: 2025 hyperpolymath
--
-- Note G Engine - Ada/SPARK Core
-- Mill-based synthesis engine for deterministic template processing

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package NoteG_Engine with SPARK_Mode => On is

   -- Maximum sizes for bounded operations
   Max_Variable_Name_Length : constant := 256;
   Max_Variable_Value_Length : constant := 65536;
   Max_Variables : constant := 1024;
   Max_Template_Size : constant := 1048576;  -- 1MB

   -- Error codes
   type Error_Code is (
      Success,
      Invalid_Template,
      Variable_Not_Found,
      Syntax_Error,
      Buffer_Overflow,
      Accessibility_Error,
      Mill_Synthesis_Error
   );

   -- Accessibility types following Note G language
   type Accessibility_Kind is (
      BSL,      -- British Sign Language
      GSL,      -- German Sign Language (Deutsche Gebärdensprache)
      ASL,      -- American Sign Language
      Makaton   -- Makaton symbol system
   );

   -- Variable store entry
   type Variable_Entry is record
      Name  : Unbounded_String;
      Value : Unbounded_String;
      A11y  : Accessibility_Kind;
      Has_A11y : Boolean;
   end record;

   -- Variable store (bounded array)
   type Variable_Store is array (1 .. Max_Variables) of Variable_Entry;

   -- Engine state
   type Engine_State is record
      Variables     : Variable_Store;
      Variable_Count : Natural range 0 .. Max_Variables;
      Last_Error    : Error_Code;
      Initialized   : Boolean;
   end record;

   -- Initialize the engine
   procedure Initialize (State : out Engine_State)
      with Post => State.Initialized and State.Variable_Count = 0;

   -- Set a variable
   procedure Set_Variable (
      State : in out Engine_State;
      Name  : in String;
      Value : in String
   ) with Pre => State.Initialized and Name'Length <= Max_Variable_Name_Length
              and Value'Length <= Max_Variable_Value_Length;

   -- Set a variable with accessibility metadata
   procedure Set_Variable_With_A11y (
      State : in out Engine_State;
      Name  : in String;
      Value : in String;
      Kind  : in Accessibility_Kind
   ) with Pre => State.Initialized and Name'Length <= Max_Variable_Name_Length
              and Value'Length <= Max_Variable_Value_Length;

   -- Get a variable value
   function Get_Variable (
      State : in Engine_State;
      Name  : in String
   ) return Unbounded_String
      with Pre => State.Initialized;

   -- Check if variable exists
   function Has_Variable (
      State : in Engine_State;
      Name  : in String
   ) return Boolean
      with Pre => State.Initialized;

   -- Process a template string
   procedure Process_Template (
      State    : in Engine_State;
      Template : in String;
      Output   : out Unbounded_String;
      Status   : out Error_Code
   ) with Pre => State.Initialized and Template'Length <= Max_Template_Size;

   -- Mill-based synthesis operation
   -- Implements deterministic template expansion following Note G semantics
   procedure Mill_Synthesize (
      State    : in Engine_State;
      Input    : in String;
      Output   : out Unbounded_String;
      Status   : out Error_Code
   ) with Pre => State.Initialized;

   -- Apply accessibility transformations
   procedure Apply_Accessibility (
      State    : in Engine_State;
      Input    : in String;
      Kind     : in Accessibility_Kind;
      Output   : out Unbounded_String;
      Status   : out Error_Code
   ) with Pre => State.Initialized;

   -- Get last error
   function Get_Last_Error (State : in Engine_State) return Error_Code
      with Pre => State.Initialized;

   -- Clear all variables
   procedure Clear_Variables (State : in out Engine_State)
      with Pre => State.Initialized,
           Post => State.Variable_Count = 0;

end NoteG_Engine;
