using System.Net.Http.Json;
using EthGraffitiExplorer.Core.DTOs;

namespace EthGraffitiExplorer.Web.Services;

public class GraffitiApiClient
{
    private readonly HttpClient _httpClient;

    public GraffitiApiClient(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<List<GraffitiDto>?> GetRecentGraffitiAsync(int count = 50)
    {
        return await _httpClient.GetFromJsonAsync<List<GraffitiDto>>($"/api/graffiti/recent?count={count}");
    }

    public async Task<PagedResult<GraffitiDto>?> SearchGraffitiAsync(GraffitiSearchRequest request)
    {
        var response = await _httpClient.PostAsJsonAsync("/api/graffiti/search", request);
        return await response.Content.ReadFromJsonAsync<PagedResult<GraffitiDto>>();
    }

    public async Task<GraffitiDto?> GetGraffitiByIdAsync(int id)
    {
        return await _httpClient.GetFromJsonAsync<GraffitiDto>($"/api/graffiti/{id}");
    }

    public async Task<List<GraffitiDto>?> GetGraffitiByValidatorAsync(int validatorIndex, int limit = 100)
    {
        return await _httpClient.GetFromJsonAsync<List<GraffitiDto>>($"/api/graffiti/validator/{validatorIndex}?limit={limit}");
    }

    public async Task<Dictionary<string, int>?> GetTopGraffitiAsync(int count = 20)
    {
        return await _httpClient.GetFromJsonAsync<Dictionary<string, int>>($"/api/graffiti/top?count={count}");
    }

    public async Task<int> GetGraffitiCountAsync()
    {
        var result = await _httpClient.GetFromJsonAsync<int>("/api/graffiti/count");
        return result;
    }

    public async Task<ValidatorDto?> GetValidatorByIndexAsync(int validatorIndex)
    {
        return await _httpClient.GetFromJsonAsync<ValidatorDto>($"/api/validators/{validatorIndex}");
    }

    public async Task<long> GetCurrentSlotAsync()
    {
        var result = await _httpClient.GetFromJsonAsync<long>("/api/beacon/current-slot");
        return result;
    }
}
