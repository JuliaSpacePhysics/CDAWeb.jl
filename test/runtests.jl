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
    include("test_restful_api.jl")
end

@testset "Master CDF lookup" begin
    CDAWeb.update_master_cdf()
    CDAWeb.find_master_cdf("dmsp-f16_ssj_precipitating-electrons-ions_00000000_v01.cdf")
    CDAWeb.find_master_cdf("psp_fld_l2_mag_rtn_4_sa_per_cyc_00000000_v01.cdf")
    CDAWeb.find_master_cdf("psp_fld_l2_mag_sc_00")
end

@testset "CDAWeb.Dataset contract" begin
    using SpaceDataModel: Testing
    t0, t1 = DateTime(2020, 1, 1), DateTime(2020, 1, 1, 1)
    empty = (DateTime(1990, 1, 1), DateTime(1990, 1, 1, 1))
    @test "DENS" in keys(CDAWeb.Dataset("PSP_SWP_SPI_SF00_L3_MOM"))
    for direct in (false, true)
        Testing.test_dataset(CDAWeb.Dataset("PSP_SWP_SPI_SF00_L3_MOM"; direct), "DENS", t0, t1; empty)
    end
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
    @test [p.name for p in products_spaces] == ["BR", "N", "T"]
    @test length.(getdata.(products_spaces, t0, t1)) == [73, 73, 73]  # hourly over [t0, t1)
    @test_throws ArgumentError @macroexpand cda"invalid_format,param"
    @test_throws AssertionError @macroexpand cda"/DENS"
    @test_throws AssertionError @macroexpand cda"DATASET/"
    @test_throws ArgumentError cda"invalid_format"(DateTime(2020, 1, 1), DateTime(2020, 1, 2))
end

@testset "Fragment-based caching" begin

    t0 = DateTime(2020, 1, 1, 2)
    t1 = DateTime(2020, 1, 4, 3)
    dataset = "OMNI_COHO1HR_MERGED_MAG_PLASMA"
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
    data2 = getdata(
        CDAWeb.Dataset("OMNI_COHO1HR_MERGED_MAG_PLASMA"; direct = true)["V"],
        DateTime(2020, 1, 2), DateTime(2020, 1, 4);
        fragment_period = Day(1)
    )
    @test data2 isa AbstractCDFVariable
    @test length(parent(data2)) > 0

    # Third request extending range - should fetch only new fragment
    data3 = getdata(
        CDAWeb.Dataset("OMNI_COHO1HR_MERGED_MAG_PLASMA"; direct = true)["V"],
        DateTime(2020, 1, 1), DateTime(2020, 1, 5);
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

# Isolated from the user's cache in ~/.cdaweb
function with_temp_cache(f)
    CDAWeb._close_cache_db!()
    home = CDAWeb.BASE_PATH[]
    return mktempdir() do dir
        CDAWeb.BASE_PATH[] = dir
        try
            f()
        finally
            CDAWeb._close_cache_db!()
            CDAWeb.BASE_PATH[] = home
        end
    end
end

@testset "Contiguous missing fragments fetched in one request" begin
    with_temp_cache() do
        get_data_files("OMNI_COHO1HR_MERGED_MAG_PLASMA", "V", DateTime(2020, 1, 1), DateTime(2020, 1, 3); fragment_period = Day(1))
        @test length(CDAWeb.cache_metadata().path) == 1
    end
end

@testset "Deleted cached file is refetched" begin
    with_temp_cache() do
        args = ("OMNI_COHO1HR_MERGED_MAG_PLASMA", "V", DateTime(2020, 1, 1), DateTime(2020, 1, 2))
        rm(only(get_data_files(args...)))
        @test all(isfile, get_data_files(args...))
    end
end

@testset "Processed files for several variables" begin
    files = get_data_files("OMNI_COHO1HR_MERGED_MAG_PLASMA", ["BR", "BT"], DateTime(2020, 1, 1), DateTime(2020, 1, 2); disable_cache = true)
    ds = CDFDataset(only(files))
    @test "BR" in keys(ds) && "BT" in keys(ds)
end

@testset "Datasets" begin
    id = "AC_H2_MFI"
    res = getmeta(CDAWeb.Dataset(id))
    @test [d.Id for d in get_datasets(; idPattern = "AC_H2_MFI")] == [id]
    @test_throws ArgumentError CDAWeb.Dataset("ac_h2_mf")
    # Virtual: the cached files hold a placeholder record
    @test size(cda"THE_L2_ESA/the_peif_en_efluxQ"("2008-02-26T04:00", "2008-02-26T05:00")) == (32, 38)
    vars = values(cda"RBSP-A_DENSITY_EMFISIS-L4")
    @test cda"RBSP-A_DENSITY_EMFISIS-L4/density" in vars && "Epoch" ∉ [v.name for v in vars]
    @test CDAWeb.Dataset(res.Doi) == CDAWeb.Dataset(res.SpaseResourceId) == CDAWeb.Dataset(id)
    t0, t1 = DateTime(2020, 1, 1), DateTime(2020, 1, 3)
    @test basename.(remotefiles(CDAWeb.Dataset(id), t0, t1)) == basename.(get_data_files(id, t0, t1))
end

@testset "Master CDFs fetched one at a time" begin
    base = CDAWeb.BASE_PATH[]
    mktempdir() do dir
        CDAWeb.BASE_PATH[] = dir
        empty!(CDAWeb._VARIABLES)
        try
            @test "Magnitude" in keys(cda"AC_H2_MFI")
            @test getmeta(cda"AC_H2_MFI/Magnitude", "UNITS") == "nT"
            @test readdir(CDAWeb._masters_path()) == ["ac_h2_mfi_00000000_v01.cdf"]
            # CDAWeb publishes no master for it
            @test isempty(keys(cda"AC_H4_EPM"))
        finally
            CDAWeb.BASE_PATH[] = base
            empty!(CDAWeb._VARIABLES)
        end
    end
end

@testset "Empty dataset" begin
    t0 = DateTime(2021, 8, 8)
    t1 = DateTime(2021, 8, 9)
    Np = CDAWeb.Dataset("WI_H1_SWE"; direct = true)["Proton_Np_nonlin"]
    @test Np(t0, t1) isa AbstractCDFVariable
    @test Np(t0, t1) isa AbstractCDFVariable
end
