"""
Rng resource, wrapping Julia's default RNG algorithm, Xoshiro256++.

The sibling Go implementation of the PWN model uses a Go port of this same
algorithm (Xoshiro256pp in its res package) for its Rand resource, so that
both implementations advance through identical raw UInt64 sequences from
the same seed.

`Base.rand(rng::Rng)` deliberately does not use Julia's own `Float64`
conversion for `Xoshiro` (which takes the high 53 bits of the raw UInt64):
Go's `math/rand/v2` always converts to `Float64` using the low 53 bits,
regardless of the underlying source, and that conversion can't be
customized per-source there. So this implementation matches Go's
convention instead, to keep both implementations' model runs reproducible
from the same seed.
"""
struct Rng
    xoshiro::Random.Xoshiro
end

Rng(seed::Integer) = Rng(Random.Xoshiro(seed))

function Base.rand(rng::Rng)
    u = rand(rng.xoshiro, UInt64)
    mask = (UInt64(1) << 53) - UInt64(1)
    return Float64(u & mask) / Float64(UInt64(1) << 53)
end
