"""
    frozen_shuffle!(rng::Random.AbstractRNG, a::AbstractVector)

In-place Fisher-Yates shuffle, deliberately re-implemented from scratch
instead of calling `Random.shuffle!`.

This is a frozen copy of the algorithm used by `Random.shuffle!` as of
Julia 1.13 (a forward Fisher-Yates using the "Nearly Division Less" ranged
sampler, see `Random`'s `SamplerRangeNDL`, https://arxiv.org/abs/1805.10941,
algorithm 5). `Random.shuffle!`'s own implementation is not a stable target:
it has changed at least three times across recent Julia releases (backward
Fisher-Yates with a masked-rejection sampler on Julia 1.10, a forward
variant of the same masked sampler on Julia 1.12, and this NDL-based
rewrite on Julia 1.13), each giving a different permutation from the same
seed. Calling `Random.shuffle!` directly would make tree selection in
[`RandomInfection`](@ref) depend on which Julia version happens to be
running.

The sibling Go implementation ports this exact algorithm (see
`pwn/util/shuffle.go`), so both implementations select the same trees from
the same seed, regardless of the installed Julia version. Only meaningful
when `rng` produces the same raw `UInt64` stream as Go's `res.Xoshiro256pp`
(true for `Rng`'s underlying `Random.Xoshiro`, see `res/rng.jl`).
"""
function frozen_shuffle!(rng::Random.AbstractRNG, a::AbstractVector)
    n = length(a)
    for i in 2:n
        j = frozen_rand_range(rng, UInt64(i)) + 1
        a[i], a[j] = a[j], a[i]
    end
    return a
end

# Draws a uniform UInt64 in [0, s) via Lemire's multiply-high method with
# rejection sampling near the bias boundary (the "Nearly Division Less"
# technique `Random.SamplerRangeNDL` uses internally).
function frozen_rand_range(rng::Random.AbstractRNG, s::UInt64)
    x = widen(rand(rng, UInt64))
    m = x * s
    lo = m % UInt64
    if lo < s
        t = (-s) % s
        while lo < t
            x = widen(rand(rng, UInt64))
            m = x * s
            lo = m % UInt64
        end
    end
    return (m >> 64) % UInt64
end
