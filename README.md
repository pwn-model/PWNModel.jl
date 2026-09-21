# PWNModel.jl

Julia implementation of the Pine Wilt Nematode model.

## Usage

Pre-compile like this:

```
julia --project=scripts -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
```

Run the default model like this:

```
julia run.jl
```

For the default model setup, see file [`scripts/run.jl`](https://github.com/pwn-model/PWNModel.jl/blob/main/scripts/run.jl).

## Build executable

```
julia --project=build build/compile.jl
```
