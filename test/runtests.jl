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

@testset "RESTful Web Services" begin
    res = get_dataviews()
    @test length(res) > 0
    @test res[1].Id == "sp_phys"

    datasets = get_datasets(; observatoryGroup = "ACE", instrument = "MAG")
    @test length(datasets) > 0

    itypes = get_instrument_types()
    @test length(itypes) > 0

    instruments = get_instruments(; instrumentType = itypes[end].Name)
    @test length(instruments) > 0

    observatories = get_observatories(; instrument = instruments[end].Name)
    @test length(observatories) == 1

    ogs = get_observatory_groups(; instrumentType = itypes[end].Name)
    @test length(ogs) > 0

    ogis = get_observatory_groups_and_instruments(; instrumentType = itypes[end].Name)
    @test length(ogis) > 0

    res = get_inventory("OMNI_COHO1HR_MERGED_MAG_PLASMA", DateTime(2020, 1, 1), DateTime(2020, 1, 2))
    @test length(res) > 0

    get_original_file_descs("OMNI_COHO1HR_MERGED_MAG_PLASMA", DateTime(2020, 1, 1), DateTime(2020, 2, 1))

    get_data_file_descs("OMNI_COHO1HR_MERGED_MAG_PLASMA", ["BR", "BT", "BN"], DateTime(2020, 1, 1), DateTime(2020, 1, 2))
    get_data_file_descs("OMNI_COHO1HR_MERGED_MAG_PLASMA", ["BR", "BT", "BN"], DateTime(2020, 1, 1), DateTime(2020, 1, 2); format = "png")

    @testset "Get variables" begin
        res = CDAWeb.get_variables("WI_H1_SWE")
        @test length(res) == 81
        @test collect(keys(res[1])) == [:Name, :ShortDescription, :LongDescription]
        names = CDAWeb.get_variable_names("WI_H1_SWE")
        @test length(names) == 81
        @test "Epoch" ∉ names
    end
end

@testset "Master CDF lookup" begin
    CDAWeb.update_master_cdf()
    CDAWeb.find_master_cdf("dmsp-f16_ssj_precipitating-electrons-ions_00000000_v01.cdf")
    CDAWeb.find_master_cdf("psp_fld_l2_mag_rtn_4_sa_per_cyc_00000000_v01.cdf")
    CDAWeb.find_master_cdf("psp_fld_l2_mag_sc_00")
end


using DimensionalData

@testset "Concatenation" begin
    data = CDAWeb.get_data("OMNI_COHO1HR_MERGED_MAG_PLASMA", DateTime(2020, 5, 2), DateTime(2020, 6, 7))["V"]
    DimArray(data)
    # 80.709 μs (382 allocs: 57.938 KiB)
end

@testset "CDAWeb data retrieval" begin
    t_start = DateTime(2020, 1, 1)
    t_stop = DateTime(2020, 1, 1, 1)

    dataset = CDAWeb.get_data("PSP_SWP_SPI_SF00_L3_MOM", t_start, t_stop)
    @test "DENS" in keys(dataset)
    dens = CDAWeb.get_data("PSP_SWP_SPI_SF00_L3_MOM", "DENS", t_start, t_stop)
    @test dens isa AbstractCDFVariable
    @test CommonDataModel.name(dens) == "DENS"
    @test length(parent(dens)) > 0

    dens2 = CDAWeb.get_data("PSP_SWP_SPI_SF00_L3_MOM/DENS", t_start, t_stop)
    @test dens2 isa AbstractCDFVariable
    @test CommonDataModel.name(dens2) == CommonDataModel.name(dens)

    @test isempty(CDAWeb.get_data("PSP_SWP_SPI_SF00_L3_MOM/DENS", DateTime(1990, 1, 1), DateTime(1990, 1, 1, 1)))
end

@testset "cda_str macro" begin
    # Test single parameter
    using Dates
    t0 = DateTime(2020, 1, 1, 2)
    t1 = DateTime(2020, 1, 4, 3)
    ds_spec = cda"OMNI_COHO1HR_MERGED_MAG_PLASMA"
    ds = ds_spec(t0, t1)
    @test ds["Epoch"][1] == t0
    # Test multiple parameters with spaces
    products_spaces = cda"OMNI_COHO1HR_MERGED_MAG_PLASMA/BR, N , T"
    @test length(products_spaces) == 3
    @test length(products_spaces(t0, t1)) == 3
    @test products_spaces[1](t0, t1) |> length == 74
    # Test error case - invalid format
    @test_throws Exception eval(:(cda"invalid_format,param"))
end

@testset "Error handling" begin
    @test_throws ArgumentError CDAWeb.get_data("invalid_format", DateTime(2020, 1, 1), DateTime(2020, 1, 2))
    @test_throws AssertionError CDAWeb.get_data("/DENS", DateTime(2020, 1, 1), DateTime(2020, 1, 2))
    @test_throws AssertionError CDAWeb.get_data("DATASET/", DateTime(2020, 1, 1), DateTime(2020, 1, 2))
end

@testset "Fragment-based caching" begin

    t0 = DateTime(2020, 1, 1, 2)
    t1 = DateTime(2020, 1, 4, 3)
    dataset = "OMNI_COHO1HR_MERGED_MAG_PLASMA"
    @test collect(CDAWeb.split_into_fragments(t0, t1, Day(1))) == [(DateTime(2020, 1, i), DateTime(2020, 1, i + 1)) for i in 1:4]

    CDAWeb.find_cached_and_missing(dataset, "V", t0, t1; fragment_period = Day(1))

    # Clear cache before test
    CDAWeb.clear_cache!(dataset)

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

@testset "Datasets" begin
    id = "AC_H2_MFI"
    res = CDAWeb.get_dataset(id)
    @test res.Id == id

    CDAWeb.get_dataset("OMNI_COHO1HR_MERGED_MAG_PLASMA", "2020-5-2", "2020-5-3")
    CDAWeb.get_dataset("OMNI_COHO1HR_MERGED_MAG_PLASMA", "1900-1-1", "1900-1-2")
end

@testset "Dataset clipping" begin
    t0 = DateTime(2020, 5, 2)
    t1 = DateTime(2020, 5, 3)
    ds_full = get_dataset("OMNI_COHO1HR_MERGED_MAG_PLASMA", t0, t1; clip = false)
    ds_clipped = get_dataset("OMNI_COHO1HR_MERGED_MAG_PLASMA", t0, t1; clip = true)
    @test ds_full.attrib == ds_clipped.attrib
    ds_full["Epoch"] |> Array
    ds_clipped["Epoch"] |> Array
end

@testset "Empty dataset" begin
    t0 = DateTime(2021, 8, 8)
    t1 = DateTime(2021, 8, 9)
    @test get_data("WI_H1_SWE", "Proton_Np_nonlin", t0, t1) isa AbstractCDFVariable
    @test get_data("WI_H1_SWE", "Proton_Np_nonlin", t0, t1) isa AbstractCDFVariable
end
