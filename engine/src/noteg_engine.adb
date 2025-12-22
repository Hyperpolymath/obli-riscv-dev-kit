-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-FileCopyrightText: 2025 hyperpolymath
--
-- Note G Engine - Ada/SPARK Core Implementation

with Ada.Strings.Fixed;

package body NoteG_Engine with SPARK_Mode => On is

   procedure Initialize (State : out Engine_State) is
   begin
      State.Variable_Count := 0;
      State.Last_Error := Success;
      State.Initialized := True;

      -- Initialize all variable entries
      for I in State.Variables'Range loop
         State.Variables (I).Name := Null_Unbounded_String;
         State.Variables (I).Value := Null_Unbounded_String;
         State.Variables (I).A11y := BSL;
         State.Variables (I).Has_A11y := False;
      end loop;
   end Initialize;

   procedure Set_Variable (
      State : in out Engine_State;
      Name  : in String;
      Value : in String
   ) is
      Name_UBS : constant Unbounded_String := To_Unbounded_String (Name);
   begin
      -- Check if variable already exists
      for I in 1 .. State.Variable_Count loop
         if State.Variables (I).Name = Name_UBS then
            State.Variables (I).Value := To_Unbounded_String (Value);
            State.Last_Error := Success;
            return;
         end if;
      end loop;

      -- Add new variable if space available
      if State.Variable_Count < Max_Variables then
         State.Variable_Count := State.Variable_Count + 1;
         State.Variables (State.Variable_Count).Name := Name_UBS;
         State.Variables (State.Variable_Count).Value := To_Unbounded_String (Value);
         State.Variables (State.Variable_Count).Has_A11y := False;
         State.Last_Error := Success;
      else
         State.Last_Error := Buffer_Overflow;
      end if;
   end Set_Variable;

   procedure Set_Variable_With_A11y (
      State : in Out Engine_State;
      Name  : in String;
      Value : in String;
      Kind  : in Accessibility_Kind
   ) is
      Name_UBS : constant Unbounded_String := To_Unbounded_String (Name);
   begin
      -- Check if variable already exists
      for I in 1 .. State.Variable_Count loop
         if State.Variables (I).Name = Name_UBS then
            State.Variables (I).Value := To_Unbounded_String (Value);
            State.Variables (I).A11y := Kind;
            State.Variables (I).Has_A11y := True;
            State.Last_Error := Success;
            return;
         end if;
      end loop;

      -- Add new variable if space available
      if State.Variable_Count < Max_Variables then
         State.Variable_Count := State.Variable_Count + 1;
         State.Variables (State.Variable_Count).Name := Name_UBS;
         State.Variables (State.Variable_Count).Value := To_Unbounded_String (Value);
         State.Variables (State.Variable_Count).A11y := Kind;
         State.Variables (State.Variable_Count).Has_A11y := True;
         State.Last_Error := Success;
      else
         State.Last_Error := Buffer_Overflow;
      end if;
   end Set_Variable_With_A11y;

   function Get_Variable (
      State : in Engine_State;
      Name  : in String
   ) return Unbounded_String is
      Name_UBS : constant Unbounded_String := To_Unbounded_String (Name);
   begin
      for I in 1 .. State.Variable_Count loop
         if State.Variables (I).Name = Name_UBS then
            return State.Variables (I).Value;
         end if;
      end loop;
      return Null_Unbounded_String;
   end Get_Variable;

   function Has_Variable (
      State : in Engine_State;
      Name  : in String
   ) return Boolean is
      Name_UBS : constant Unbounded_String := To_Unbounded_String (Name);
   begin
      for I in 1 .. State.Variable_Count loop
         if State.Variables (I).Name = Name_UBS then
            return True;
         end if;
      end loop;
      return False;
   end Has_Variable;

   procedure Process_Template (
      State    : in Engine_State;
      Template : in String;
      Output   : out Unbounded_String;
      Status   : out Error_Code
   ) is
      Pos        : Natural := Template'First;
      Open_Pos   : Natural;
      Close_Pos  : Natural;
      Var_Name   : Unbounded_String;
      Var_Value  : Unbounded_String;
   begin
      Output := Null_Unbounded_String;
      Status := Success;

      while Pos <= Template'Last loop
         -- Look for {{ opening
         Open_Pos := Ada.Strings.Fixed.Index (Template (Pos .. Template'Last), "{{");

         if Open_Pos = 0 then
            -- No more templates, append rest
            Append (Output, Template (Pos .. Template'Last));
            exit;
         end if;

         -- Append text before template
         if Open_Pos > Pos then
            Append (Output, Template (Pos .. Open_Pos - 1));
         end if;

         -- Find closing }}
         Close_Pos := Ada.Strings.Fixed.Index (Template (Open_Pos + 2 .. Template'Last), "}}");

         if Close_Pos = 0 then
            Status := Syntax_Error;
            return;
         end if;

         -- Extract variable name (trim whitespace)
         declare
            Raw_Name : constant String := Template (Open_Pos + 2 .. Close_Pos - 1);
            Trimmed  : constant String := Ada.Strings.Fixed.Trim (Raw_Name, Ada.Strings.Both);
         begin
            Var_Name := To_Unbounded_String (Trimmed);
         end;

         -- Look up variable
         if Has_Variable (State, To_String (Var_Name)) then
            Var_Value := Get_Variable (State, To_String (Var_Name));
            Append (Output, Var_Value);
         else
            -- Variable not found - keep original or emit error
            Append (Output, "{{" & To_String (Var_Name) & "}}");
         end if;

         Pos := Close_Pos + 2;
      end loop;
   end Process_Template;

   procedure Mill_Synthesize (
      State    : in Engine_State;
      Input    : in String;
      Output   : out Unbounded_String;
      Status   : out Error_Code
   ) is
   begin
      -- Mill synthesis implements deterministic template expansion
      -- following the operation-card model from historical computing
      Process_Template (State, Input, Output, Status);

      if Status = Success then
         -- Apply post-processing passes (future: multiple synthesis phases)
         null;
      end if;
   end Mill_Synthesize;

   procedure Apply_Accessibility (
      State    : in Engine_State;
      Input    : in String;
      Kind     : in Accessibility_Kind;
      Output   : out Unbounded_String;
      Status   : out Error_Code
   ) is
      pragma Unreferenced (State);
      Lang_Code : Unbounded_String;
      Class_Name : Unbounded_String;
   begin
      -- Determine language code and class based on accessibility kind
      case Kind is
         when BSL =>
            Lang_Code := To_Unbounded_String ("bfi");
            Class_Name := To_Unbounded_String ("a11y-bsl");
         when GSL =>
            Lang_Code := To_Unbounded_String ("gsg");
            Class_Name := To_Unbounded_String ("a11y-gsl");
         when ASL =>
            Lang_Code := To_Unbounded_String ("ase");
            Class_Name := To_Unbounded_String ("a11y-asl");
         when Makaton =>
            Lang_Code := To_Unbounded_String ("en");
            Class_Name := To_Unbounded_String ("a11y-makaton");
      end case;

      -- Wrap content with accessibility markup
      Output := To_Unbounded_String ("<span class=""");
      Append (Output, Class_Name);
      Append (Output, """ lang=""");
      Append (Output, Lang_Code);
      Append (Output, """ role=""note"">");
      Append (Output, Input);
      Append (Output, "</span>");

      Status := Success;
   end Apply_Accessibility;

   function Get_Last_Error (State : in Engine_State) return Error_Code is
   begin
      return State.Last_Error;
   end Get_Last_Error;

   procedure Clear_Variables (State : in out Engine_State) is
   begin
      State.Variable_Count := 0;
      State.Last_Error := Success;
   end Clear_Variables;

end NoteG_Engine;
