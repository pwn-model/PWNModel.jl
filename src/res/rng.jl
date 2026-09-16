"""
Port of the PCG-DXSM generator from Go's `math/rand/v2` package
(https://cs.opensource.google/go/go/+/refs/tags/go1.23.0:src/math/rand/v2/pcg.go),
so that this Julia implementation and the sibling Go implementation of the PWN
model produce identical random sequences from the same seed.
"""
const _PCG_MUL = (UInt128(2549297995355413924) << 64) | UInt128(4865540595714422341)
const _PCG_INC = (UInt128(6364136223846793005) << 64) | UInt128(1442695040888963407)
const _PCG_CHEAP_MUL = UInt64(0xda942042e4dd58b5)

mutable struct Rng
    state::UInt128
end

Rng(seed::Integer) = Rng(UInt128(seed % UInt64))

function _next_uint64!(rng::Rng)
    rng.state = rng.state * _PCG_MUL + _PCG_INC
    hi = UInt64(rng.state >> 64)
    lo = UInt64(rng.state & typemax(UInt64))

    hi = xor(hi, hi >> 32)
    hi *= _PCG_CHEAP_MUL
    hi = xor(hi, hi >> 48)
    hi *= (lo | UInt64(1))
    return hi
end

function Base.rand(rng::Rng)
    mask = (UInt64(1) << 53) - UInt64(1)
    return Float64(_next_uint64!(rng) & mask) / Float64(UInt64(1) << 53)
end
