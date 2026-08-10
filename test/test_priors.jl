using HeartRateLab: HeartRateLab
using Test
import Distributions

cd(@__DIR__)

# d-14: tests for the normative-priors subsystem (pure parse/round-trip logic; no display).
# Exercises load_normative_priors!, normative_prior, prior_call_string, prior_registry,
# and the internals _parse_csv_line / _reconstruct_distribution.

const F = HeartRateLab.Features

@testset "Normative priors" begin

    @testset "auto-loaded registry" begin
        # docs/normative_priors.csv is auto-loaded at module init.
        @test HeartRateLab.prior_registry isa AbstractDict
        @test !isempty(HeartRateLab.prior_registry)

        # Every loaded prior is a concrete Distributions.jl distribution.
        k = first(keys(HeartRateLab.prior_registry))
        @test HeartRateLab.normative_prior(k) isa Distributions.Distribution
        @test HeartRateLab.normative_prior(k) === HeartRateLab.prior_registry[k]

        # Unknown feature → nothing / "nothing".
        @test HeartRateLab.normative_prior("__no_such_feature__") === nothing
        @test HeartRateLab.prior_call_string("__no_such_feature__") == "nothing"

        # prior_call_string round-trips the constructor string for a real feature.
        @test HeartRateLab.prior_call_string(k) == string(HeartRateLab.prior_registry[k])
    end

    @testset "_parse_csv_line (quoted commas)" begin
        # A quoted field containing commas must stay a single field.
        fields = F._parse_csv_line("rmssd,\"Gamma(1.2, 26.7)\",ok")
        @test fields == ["rmssd", "Gamma(1.2, 26.7)", "ok"]
        @test length(F._parse_csv_line("a,b,c,d")) == 4
        @test F._parse_csv_line("") == [""]
    end

    @testset "_reconstruct_distribution (every family + NaN guard)" begin
        @test F._reconstruct_distribution("Normal", "μ", 0.0, "σ", 1.0) == Distributions.Normal(0.0, 1.0)
        @test F._reconstruct_distribution("Gamma", "α", 2.0, "θ", 3.0) == Distributions.Gamma(2.0, 3.0)
        @test F._reconstruct_distribution("Beta", "α", 2.0, "β", 5.0) == Distributions.Beta(2.0, 5.0)
        @test F._reconstruct_distribution("LogNormal", "μ", 1.0, "σ", 0.5) == Distributions.LogNormal(1.0, 0.5)
        # NaN / missing params → nothing
        @test F._reconstruct_distribution("Normal", "μ", NaN, "σ", 1.0) === nothing
        @test F._reconstruct_distribution("Normal", "μ", 0.0, "σ", NaN) === nothing
        # Unknown family → nothing
        @test F._reconstruct_distribution("Weibull", "a", 1.0, "b", 2.0) === nothing
    end

    @testset "load_normative_priors! round-trip (temp CSV)" begin
        header = "feature,family,param1_name,param1_value,param2_name,param2_value,status"
        rows = [
            "t_normal,Normal,mu,800.0,sigma,50.0,ok",
            "t_gamma,Gamma,alpha,2.0,theta,26.7,ok",
            "t_beta,Beta,alpha,2.0,beta,5.0,ok",
            "t_lognormal,LogNormal,mu,6.6,sigma,0.88,ok",
            "t_skipped,Normal,mu,1.0,sigma,1.0,not in CSV",  # non-ok status → skipped
        ]
        tmp = tempname() * ".csv"
        open(tmp, "w") do io
            println(io, header)
            for r in rows
                println(io, r)
            end
        end

        n = HeartRateLab.load_normative_priors!(tmp)
        @test n == 4  # 4 ok rows, the not-ok one skipped

        @test HeartRateLab.normative_prior("t_normal") == Distributions.Normal(800.0, 50.0)
        @test HeartRateLab.normative_prior("t_gamma") == Distributions.Gamma(2.0, 26.7)
        @test HeartRateLab.normative_prior("t_beta") == Distributions.Beta(2.0, 5.0)
        @test HeartRateLab.normative_prior("t_lognormal") == Distributions.LogNormal(6.6, 0.88)
        @test HeartRateLab.normative_prior("t_skipped") === nothing
        @test HeartRateLab.prior_call_string("t_gamma") == string(Distributions.Gamma(2.0, 26.7))

        rm(tmp; force=true)
    end

    @testset "errors" begin
        @test_throws ErrorException HeartRateLab.load_normative_priors!("/no/such/priors.csv")
    end
end
