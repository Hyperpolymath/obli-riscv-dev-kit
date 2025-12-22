// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 hyperpolymath
// Note G Language - Interpreter

open Types

// Runtime values
type rec value =
  | VNull
  | VBool(bool)
  | VNumber(float)
  | VString(string)
  | VArray(array<value>)
  | VObject(Belt.Map.String.t<value>)
  | VFunction({params: array<string>, body: block, closure: environment})
  | VBuiltin(string, array<value> => result<value>)
  | VAccessibility({kind: accessibilityKind, data: value})

and environment = {
  values: Belt.Map.String.t<ref<value>>,
  parent: option<environment>,
}

type interpreter = {
  mutable env: environment,
  mutable output: array<string>,
}

let emptyEnv = (): environment => {
  values: Belt.Map.String.empty,
  parent: None,
}

let extendEnv = (parent: environment): environment => {
  values: Belt.Map.String.empty,
  parent: Some(parent),
}

let rec lookupVar = (env: environment, name: string): option<ref<value>> => {
  switch Belt.Map.String.get(env.values, name) {
  | Some(v) => Some(v)
  | None =>
    switch env.parent {
    | Some(parent) => lookupVar(parent, name)
    | None => None
    }
  }
}

let defineVar = (env: environment, name: string, value: value): environment => {
  ...env,
  values: Belt.Map.String.set(env.values, name, ref(value)),
}

let assignVar = (env: environment, name: string, value: value): result<unit> => {
  switch lookupVar(env, name) {
  | Some(r) =>
    r := value
    Ok()
  | None =>
    Error({
      kind: RuntimeError(`Undefined variable: ${name}`),
      message: `Variable '${name}' is not defined`,
      span: None,
    })
  }
}

// Built-in functions
let builtins: Belt.Map.String.t<array<value> => result<value>> = Belt.Map.String.fromArray([
  ("print", args => {
    args->Belt.Array.forEach(arg => {
      switch arg {
      | VString(s) => Js.Console.log(s)
      | VNumber(n) => Js.Console.log(Float.toString(n))
      | VBool(b) => Js.Console.log(b ? "true" : "false")
      | VNull => Js.Console.log("null")
      | _ => Js.Console.log("[object]")
      }
    })
    Ok(VNull)
  }),
  ("len", args => {
    switch Belt.Array.get(args, 0) {
    | Some(VString(s)) => Ok(VNumber(Float.fromInt(String.length(s))))
    | Some(VArray(arr)) => Ok(VNumber(Float.fromInt(Belt.Array.length(arr))))
    | _ => Error({
        kind: RuntimeError("Invalid argument"),
        message: "len() requires a string or array",
        span: None,
      })
    }
  }),
  ("upper", args => {
    switch Belt.Array.get(args, 0) {
    | Some(VString(s)) => Ok(VString(Js.String.toUpperCase(s)))
    | _ => Error({
        kind: RuntimeError("Invalid argument"),
        message: "upper() requires a string",
        span: None,
      })
    }
  }),
  ("lower", args => {
    switch Belt.Array.get(args, 0) {
    | Some(VString(s)) => Ok(VString(Js.String.toLowerCase(s)))
    | _ => Error({
        kind: RuntimeError("Invalid argument"),
        message: "lower() requires a string",
        span: None,
      })
    }
  }),
  ("escape_html", args => {
    switch Belt.Array.get(args, 0) {
    | Some(VString(s)) =>
      let escaped = s
        ->Js.String.replaceByRe(%re("/&/g"), "&amp;")
        ->Js.String.replaceByRe(%re("/</g"), "&lt;")
        ->Js.String.replaceByRe(%re("/>/g"), "&gt;")
        ->Js.String.replaceByRe(%re("/\"/g"), "&quot;")
        ->Js.String.replaceByRe(%re("/'/g"), "&#39;")
      Ok(VString(escaped))
    | _ => Error({
        kind: RuntimeError("Invalid argument"),
        message: "escape_html() requires a string",
        span: None,
      })
    }
  }),
  ("date", args => {
    let now = Js.Date.make()
    switch Belt.Array.get(args, 0) {
    | Some(VString("iso")) => Ok(VString(Js.Date.toISOString(now)))
    | Some(VString("date")) => Ok(VString(Js.Date.toDateString(now)))
    | _ => Ok(VString(Js.Date.toString(now)))
    }
  }),
  ("join", args => {
    switch (Belt.Array.get(args, 0), Belt.Array.get(args, 1)) {
    | (Some(VArray(arr)), Some(VString(sep))) =>
      let strings = arr->Belt.Array.map(v => {
        switch v {
        | VString(s) => s
        | VNumber(n) => Float.toString(n)
        | VBool(b) => b ? "true" : "false"
        | VNull => "null"
        | _ => "[object]"
        }
      })
      Ok(VString(Js.Array2.joinWith(strings, sep)))
    | _ => Error({
        kind: RuntimeError("Invalid arguments"),
        message: "join() requires an array and separator",
        span: None,
      })
    }
  }),
])

let make = (): interpreter => {
  let env = emptyEnv()
  // Add builtins to environment
  let envWithBuiltins = Belt.Map.String.reduce(builtins, env, (acc, name, fn) => {
    defineVar(acc, name, VBuiltin(name, fn))
  })
  {env: envWithBuiltins, output: []}
}

let valueToString = (v: value): string => {
  switch v {
  | VNull => "null"
  | VBool(b) => b ? "true" : "false"
  | VNumber(n) => Float.toString(n)
  | VString(s) => s
  | VArray(arr) =>
    let items = arr->Belt.Array.map(valueToString)->Js.Array2.joinWith(", ")
    `[${items}]`
  | VObject(obj) =>
    let pairs = Belt.Map.String.toArray(obj)->Belt.Array.map(((k, v)) => {
      `${k}: ${valueToString(v)}`
    })->Js.Array2.joinWith(", ")
    `{${pairs}}`
  | VFunction(_) => "[function]"
  | VBuiltin(name, _) => `[builtin: ${name}]`
  | VAccessibility({kind, data}) =>
    let kindStr = switch kind {
    | BSLKind => "bsl"
    | GSLKind => "gsl"
    | ASLKind => "asl"
    | MakatonKind => "makaton"
    }
    `[accessibility:${kindStr}] ${valueToString(data)}`
  }
}

let isTruthy = (v: value): bool => {
  switch v {
  | VNull => false
  | VBool(b) => b
  | VNumber(n) => n != 0.0
  | VString(s) => String.length(s) > 0
  | VArray(arr) => Belt.Array.length(arr) > 0
  | _ => true
  }
}

let rec evalExpr = (interp: interpreter, expr: expr): result<value> => {
  switch expr {
  | LiteralExpr(lit) =>
    switch lit {
    | StringLit(s) => Ok(VString(s))
    | NumberLit(n) => Ok(VNumber(n))
    | BoolLit(b) => Ok(VBool(b))
    | NullLit => Ok(VNull)
    }

  | IdentifierExpr(name) =>
    switch lookupVar(interp.env, name) {
    | Some(r) => Ok(r.contents)
    | None =>
      Error({
        kind: RuntimeError(`Undefined variable: ${name}`),
        message: `Variable '${name}' is not defined`,
        span: None,
      })
    }

  | BinaryExpr({left, op, right}) =>
    switch evalExpr(interp, left) {
    | Error(e) => Error(e)
    | Ok(leftVal) =>
      switch evalExpr(interp, right) {
      | Error(e) => Error(e)
      | Ok(rightVal) => evalBinaryOp(op, leftVal, rightVal)
      }
    }

  | UnaryExpr({op, operand}) =>
    switch evalExpr(interp, operand) {
    | Error(e) => Error(e)
    | Ok(val_) =>
      switch op {
      | Negate =>
        switch val_ {
        | VNumber(n) => Ok(VNumber(-.n))
        | _ => Error({
            kind: RuntimeError("Invalid operand"),
            message: "Cannot negate non-number",
            span: None,
          })
        }
      | NotOp => Ok(VBool(!isTruthy(val_)))
      }
    }

  | CallExpr({callee, args}) =>
    switch evalExpr(interp, callee) {
    | Error(e) => Error(e)
    | Ok(calleeVal) =>
      let rec evalArgs = (remaining: array<expr>, acc: array<value>): result<array<value>> => {
        switch Belt.Array.get(remaining, 0) {
        | None => Ok(acc)
        | Some(arg) =>
          switch evalExpr(interp, arg) {
          | Error(e) => Error(e)
          | Ok(val_) =>
            evalArgs(
              Belt.Array.sliceToEnd(remaining, 1),
              Belt.Array.concat(acc, [val_]),
            )
          }
        }
      }
      switch evalArgs(args, []) {
      | Error(e) => Error(e)
      | Ok(argVals) =>
        switch calleeVal {
        | VBuiltin(_, fn) => fn(argVals)
        | VFunction({params, body, closure}) =>
          if Belt.Array.length(params) != Belt.Array.length(argVals) {
            Error({
              kind: RuntimeError("Arity mismatch"),
              message: `Expected ${Belt.Int.toString(Belt.Array.length(params))} arguments, got ${Belt.Int.toString(Belt.Array.length(argVals))}`,
              span: None,
            })
          } else {
            // Create new environment with parameters
            let fnEnv = Belt.Array.reduceWithIndex(params, extendEnv(closure), (env, param, i) => {
              switch Belt.Array.get(argVals, i) {
              | Some(val_) => defineVar(env, param, val_)
              | None => env
              }
            })
            let savedEnv = interp.env
            interp.env = fnEnv
            let result = evalBlock(interp, body)
            interp.env = savedEnv
            result
          }
        | _ =>
          Error({
            kind: RuntimeError("Not callable"),
            message: "Can only call functions",
            span: None,
          })
        }
      }
    }

  | ArrayExpr(elements) =>
    let rec evalElements = (remaining: array<expr>, acc: array<value>): result<array<value>> => {
      switch Belt.Array.get(remaining, 0) {
      | None => Ok(acc)
      | Some(el) =>
        switch evalExpr(interp, el) {
        | Error(e) => Error(e)
        | Ok(val_) =>
          evalElements(
            Belt.Array.sliceToEnd(remaining, 1),
            Belt.Array.concat(acc, [val_]),
          )
        }
      }
    }
    switch evalElements(elements, []) {
    | Error(e) => Error(e)
    | Ok(vals) => Ok(VArray(vals))
    }

  | ObjectExpr(pairs) =>
    let rec evalPairs = (
      remaining: array<(string, expr)>,
      acc: Belt.Map.String.t<value>,
    ): result<Belt.Map.String.t<value>> => {
      switch Belt.Array.get(remaining, 0) {
      | None => Ok(acc)
      | Some((key, valExpr)) =>
        switch evalExpr(interp, valExpr) {
        | Error(e) => Error(e)
        | Ok(val_) =>
          evalPairs(
            Belt.Array.sliceToEnd(remaining, 1),
            Belt.Map.String.set(acc, key, val_),
          )
        }
      }
    }
    switch evalPairs(pairs, Belt.Map.String.empty) {
    | Error(e) => Error(e)
    | Ok(obj) => Ok(VObject(obj))
    }

  | TemplateExpr({parts}) =>
    let rec evalParts = (remaining: array<templatePart>, acc: string): result<string> => {
      switch Belt.Array.get(remaining, 0) {
      | None => Ok(acc)
      | Some(part) =>
        switch part {
        | TextPart(text) =>
          evalParts(Belt.Array.sliceToEnd(remaining, 1), acc ++ text)
        | ExprPart(e) =>
          switch evalExpr(interp, e) {
          | Error(err) => Error(err)
          | Ok(val_) =>
            evalParts(Belt.Array.sliceToEnd(remaining, 1), acc ++ valueToString(val_))
          }
        | FilterPart({expr: e, filter}) =>
          switch evalExpr(interp, e) {
          | Error(err) => Error(err)
          | Ok(val_) =>
            switch lookupVar(interp.env, filter) {
            | Some(r) =>
              switch r.contents {
              | VBuiltin(_, fn) =>
                switch fn([val_]) {
                | Error(err) => Error(err)
                | Ok(filtered) =>
                  evalParts(Belt.Array.sliceToEnd(remaining, 1), acc ++ valueToString(filtered))
                }
              | VFunction({params, body, closure}) =>
                if Belt.Array.length(params) != 1 {
                  Error({
                    kind: RuntimeError("Filter arity"),
                    message: "Filter function must take exactly one argument",
                    span: None,
                  })
                } else {
                  let fnEnv = defineVar(extendEnv(closure), Belt.Array.getExn(params, 0), val_)
                  let savedEnv = interp.env
                  interp.env = fnEnv
                  let result = evalBlock(interp, body)
                  interp.env = savedEnv
                  switch result {
                  | Error(err) => Error(err)
                  | Ok(filtered) =>
                    evalParts(Belt.Array.sliceToEnd(remaining, 1), acc ++ valueToString(filtered))
                  }
                }
              | _ =>
                Error({
                  kind: RuntimeError("Invalid filter"),
                  message: `'${filter}' is not a function`,
                  span: None,
                })
              }
            | None =>
              Error({
                kind: RuntimeError(`Unknown filter: ${filter}`),
                message: `Filter '${filter}' is not defined`,
                span: None,
              })
            }
          }
        }
      }
    }
    switch evalParts(parts, "") {
    | Error(e) => Error(e)
    | Ok(s) => Ok(VString(s))
    }

  | AccessibilityExpr({kind, content}) =>
    switch evalExpr(interp, content) {
    | Error(e) => Error(e)
    | Ok(data) => Ok(VAccessibility({kind, data}))
    }
  }
}

and evalBinaryOp = (op: binaryOp, left: value, right: value): result<value> => {
  switch op {
  | Add =>
    switch (left, right) {
    | (VNumber(a), VNumber(b)) => Ok(VNumber(a +. b))
    | (VString(a), VString(b)) => Ok(VString(a ++ b))
    | (VString(a), b) => Ok(VString(a ++ valueToString(b)))
    | (a, VString(b)) => Ok(VString(valueToString(a) ++ b))
    | _ => Error({kind: RuntimeError("Invalid operands"), message: "Cannot add these types", span: None})
    }
  | Sub =>
    switch (left, right) {
    | (VNumber(a), VNumber(b)) => Ok(VNumber(a -. b))
    | _ => Error({kind: RuntimeError("Invalid operands"), message: "Cannot subtract non-numbers", span: None})
    }
  | Mul =>
    switch (left, right) {
    | (VNumber(a), VNumber(b)) => Ok(VNumber(a *. b))
    | _ => Error({kind: RuntimeError("Invalid operands"), message: "Cannot multiply non-numbers", span: None})
    }
  | Div =>
    switch (left, right) {
    | (VNumber(_), VNumber(0.0)) => Error({kind: RuntimeError("Division by zero"), message: "Cannot divide by zero", span: None})
    | (VNumber(a), VNumber(b)) => Ok(VNumber(a /. b))
    | _ => Error({kind: RuntimeError("Invalid operands"), message: "Cannot divide non-numbers", span: None})
    }
  | Eq => Ok(VBool(left == right))
  | Neq => Ok(VBool(left != right))
  | Lt =>
    switch (left, right) {
    | (VNumber(a), VNumber(b)) => Ok(VBool(a < b))
    | (VString(a), VString(b)) => Ok(VBool(a < b))
    | _ => Error({kind: RuntimeError("Invalid operands"), message: "Cannot compare these types", span: None})
    }
  | Gt =>
    switch (left, right) {
    | (VNumber(a), VNumber(b)) => Ok(VBool(a > b))
    | (VString(a), VString(b)) => Ok(VBool(a > b))
    | _ => Error({kind: RuntimeError("Invalid operands"), message: "Cannot compare these types", span: None})
    }
  | Lte =>
    switch (left, right) {
    | (VNumber(a), VNumber(b)) => Ok(VBool(a <= b))
    | (VString(a), VString(b)) => Ok(VBool(a <= b))
    | _ => Error({kind: RuntimeError("Invalid operands"), message: "Cannot compare these types", span: None})
    }
  | Gte =>
    switch (left, right) {
    | (VNumber(a), VNumber(b)) => Ok(VBool(a >= b))
    | (VString(a), VString(b)) => Ok(VBool(a >= b))
    | _ => Error({kind: RuntimeError("Invalid operands"), message: "Cannot compare these types", span: None})
    }
  | AndOp => Ok(VBool(isTruthy(left) && isTruthy(right)))
  | OrOp => Ok(VBool(isTruthy(left) || isTruthy(right)))
  | Pipe =>
    switch right {
    | VBuiltin(_, fn) => fn([left])
    | VFunction({params, body, closure}) =>
      if Belt.Array.length(params) != 1 {
        Error({kind: RuntimeError("Pipe arity"), message: "Piped function must take one argument", span: None})
      } else {
        // This needs interpreter context, return error for now
        Error({kind: RuntimeError("Pipe context"), message: "Pipe operator needs full interpreter context", span: None})
      }
    | _ => Error({kind: RuntimeError("Invalid pipe"), message: "Can only pipe to functions", span: None})
    }
  }
}

and evalStmt = (interp: interpreter, stmt: stmt): result<value> => {
  switch stmt {
  | LetStmt({name, value, mutable_: _}) =>
    switch evalExpr(interp, value) {
    | Error(e) => Error(e)
    | Ok(val_) =>
      interp.env = defineVar(interp.env, name, val_)
      Ok(VNull)
    }

  | ExprStmt(expr) => evalExpr(interp, expr)

  | IfStmt({condition, then_, else_}) =>
    switch evalExpr(interp, condition) {
    | Error(e) => Error(e)
    | Ok(condVal) =>
      if isTruthy(condVal) {
        evalBlock(interp, then_)
      } else {
        switch else_ {
        | Some(elseBlock) => evalBlock(interp, elseBlock)
        | None => Ok(VNull)
        }
      }
    }

  | ForStmt({variable, iterable, body}) =>
    switch evalExpr(interp, iterable) {
    | Error(e) => Error(e)
    | Ok(iterVal) =>
      switch iterVal {
      | VArray(arr) =>
        let result = ref(Ok(VNull))
        arr->Belt.Array.forEach(item => {
          if Belt.Result.isOk(result.contents) {
            interp.env = defineVar(interp.env, variable, item)
            result := evalBlock(interp, body)
          }
        })
        result.contents
      | _ =>
        Error({
          kind: RuntimeError("Not iterable"),
          message: "Can only iterate over arrays",
          span: None,
        })
      }
    }

  | WhileStmt({condition, body}) =>
    let result = ref(Ok(VNull))
    let continue = ref(true)
    while continue.contents && Belt.Result.isOk(result.contents) {
      switch evalExpr(interp, condition) {
      | Error(e) =>
        result := Error(e)
        continue := false
      | Ok(condVal) =>
        if isTruthy(condVal) {
          result := evalBlock(interp, body)
        } else {
          continue := false
        }
      }
    }
    result.contents

  | FunctionStmt({name, params, body}) =>
    let fn = VFunction({params, body, closure: interp.env})
    interp.env = defineVar(interp.env, name, fn)
    Ok(VNull)

  | ReturnStmt(exprOpt) =>
    switch exprOpt {
    | None => Ok(VNull)
    | Some(expr) => evalExpr(interp, expr)
    }

  | ImportStmt(_) =>
    // Import handling would require file system access
    Ok(VNull)

  | ExportStmt(_) =>
    // Export handling for module system
    Ok(VNull)

  | ComponentStmt({name, props, body}) =>
    // Components are like functions that return template output
    let fn = VFunction({params: props, body, closure: interp.env})
    interp.env = defineVar(interp.env, name, fn)
    Ok(VNull)

  | AccessibilityStmt({kind, metadata}) =>
    switch evalExpr(interp, metadata) {
    | Error(e) => Error(e)
    | Ok(data) => Ok(VAccessibility({kind, data}))
    }
  }
}

and evalBlock = (interp: interpreter, block: block): result<value> => {
  let savedEnv = interp.env
  interp.env = extendEnv(interp.env)
  let result = ref(Ok(VNull))

  block->Belt.Array.forEach(stmt => {
    if Belt.Result.isOk(result.contents) {
      result := evalStmt(interp, stmt)
    }
  })

  interp.env = savedEnv
  result.contents
}

let run = (program: program): result<value> => {
  let interp = make()
  let result = ref(Ok(VNull))

  program.statements->Belt.Array.forEach(stmt => {
    if Belt.Result.isOk(result.contents) {
      result := evalStmt(interp, stmt)
    }
  })

  result.contents
}

let interpret = (source: string): result<value> => {
  switch Lexer.tokenize(source) {
  | Error(e) => Error(e)
  | Ok(tokens) =>
    switch Parser.parse(tokens) {
    | Error(e) => Error(e)
    | Ok(program) => run(program)
    }
  }
}
