struct Rng
    pcg::PCGStateOneseq{UInt128,Val{:XSH_RS},UInt64}
end

Rng(seed::Integer) = Rng(PCGStateOneseq(UInt64, seed))

Base.rand(rng::Rng, args...) = rand(rng.pcg, args...)
