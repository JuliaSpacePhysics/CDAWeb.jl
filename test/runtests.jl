using CDAWeb
using CDFDatasets
using CDFDatasets: AbstractCDFVariable
using CDFDatasets.CommonDataModel
using Dates
using Test

@testset "Aqua" begin
    using Aqua
    Aqua.test_all(CDAWeb)
end

@testset "Master CDF lookup" begin
    CDAWeb.update_master_cdf()
    CDAWeb.find_master_cdf("dmsp-f16_ssj_precipitating-electrons-ions_00000000_v01.cdf")
    CDAWeb.find_master_cdf("psp_fld_l2_mag_rtn_4_sa_per_cyc_00000000_v01.cdf")
    CDAWeb.find_master_cdf("psp_fld_l2_mag_sc_00")
end


using DimensionalData

@testset "Concatenation" begin
    data = CDAWeb.get_data("OMNI_COHO1HR_MERGED_MAG_PLASMA", "V", DateTime(2020, 5, 2), DateTime(2020, 6, 7); orig = true)
    DimArray(CDAWeb.get_data("OMNI_COHO1HR_MERGED_MAG_PLASMA", "V", DateTime(2020, 5, 2), DateTime(2020, 6, 7); orig = true))
    # 80.709 μs (382 allocs: 57.938 KiB)
end

@testset "CDAWeb data retrieval" begin
    t_start = DateTime(2020, 1, 1)
    t_stop = DateTime(2020, 1, 1, 1)

    dens = CDAWeb.get_data("PSP_SWP_SPI_SF00_L3_MOM", "DENS", t_start, t_stop)
    @test dens isa AbstractCDFVariable
    @test CommonDataModel.name(dens) == "DENS"
    @test length(parent(dens)) > 0

    dens2 = CDAWeb.get_data("PSP_SWP_SPI_SF00_L3_MOM/DENS", t_start, t_stop)
    @test dens2 isa AbstractCDFVariable
    @test CommonDataModel.name(dens2) == CommonDataModel.name(dens)

    @test_throws "404" CDAWeb.get_data("PSP_SWP_SPI_SF00_L3_MOM/DENS", DateTime(1990, 1, 1), DateTime(1990, 1, 1, 1))
end

@testset "Error handling" begin
    @test_throws AssertionError CDAWeb.get_data("invalid_format", DateTime(2020, 1, 1), DateTime(2020, 1, 2))
    @test_throws AssertionError CDAWeb.get_data("/DENS", DateTime(2020, 1, 1), DateTime(2020, 1, 2))
    @test_throws AssertionError CDAWeb.get_data("DATASET/", DateTime(2020, 1, 1), DateTime(2020, 1, 2))
end

@testset "Fragment-based caching" begin

    t0 = DateTime(2020, 1, 1, 2)
    t1 = DateTime(2020, 1, 4, 3)
    dataset = "OMNI_COHO1HR_MERGED_MAG_PLASMA"
    variable = "V"
    @test collect(CDAWeb.split_into_fragments(t0, t1, Day(1))) == [(DateTime(2020, 1, i), DateTime(2020, 1, i + 1)) for i in 1:4]

    CDAWeb.find_cached_and_missing("OMNI_COHO1HR_MERGED_MAG_PLASMA", "V", t0, t1, Day(1))

    # Clear cache before test
    CDAWeb.clear_cache!("OMNI_COHO1HR_MERGED_MAG_PLASMA")

    # First request - should fetch from API
    data1 = CDAWeb.get_data_files(
        "OMNI_COHO1HR_MERGED_MAG_PLASMA", "V",
        DateTime(2020, 1, 1), DateTime(2020, 1, 3),
        fragment_period = Day(1)
    )
    @test data1 isa Vector{String}
    @test length(parent(data1)) > 0

    # Second request overlapping with first - should use cached fragments
    data2 = CDAWeb.get_data(
        "OMNI_COHO1HR_MERGED_MAG_PLASMA", "V",
        DateTime(2020, 1, 2), DateTime(2020, 1, 4),
        fragment_period = Day(1)
    )
    @test data2 isa AbstractCDFVariable
    @test length(parent(data2)) > 0

    # Third request extending range - should fetch only new fragment
    data3 = CDAWeb.get_data(
        "OMNI_COHO1HR_MERGED_MAG_PLASMA", "V",
        DateTime(2020, 1, 1), DateTime(2020, 1, 5),
        fragment_period = Day(1)
    )
    @test data3 isa AbstractCDFVariable
    @test length(parent(data3)) > 0

    start_times = CDAWeb.cache_metadata().start_time
    @test start_times isa Vector{DateTime}
    @test length(start_times) > 0
    CDAWeb.clear_cache!()
    @test length(CDAWeb.cache_metadata().start_time) == 0
end

@testset "Variables" begin
    res = CDAWeb.get_variables("WI_H1_SWE")
    @test length(res) == 81
    @test collect(keys(res[1])) == [:Name, :ShortDescription, :LongDescription]
end

@testset "Datasets" begin
    res = CDAWeb.get_datasets(; observatoryGroup = "ACE", instrumentType = "Magnetic Fields (space)")
    @test length(res) > 0

    id = "AC_H2_MFI"
    res = CDAWeb.get_dataset(id)
    @test res.Id == id
end
