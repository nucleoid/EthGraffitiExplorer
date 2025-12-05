using System.Net.Http.Json;
using EthGraffitiExplorer.Core.DTOs;

namespace EthGraffitiExplorer.Mobile.Services;

public class GraffitiApiService
{
    private readonly HttpClient _httpClient;

    public GraffitiApiService(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<List<GraffitiDto>?> GetRecentGraffitiAsync(int count = 50)
    {
        try
        {
            return await _httpClient.GetFromJsonAsync<List<GraffitiDto>>($"/api/graffiti/recent?count={count}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error getting recent graffiti: {ex.Message}");
            return null;
        }
    }

    public async Task<PagedResult<GraffitiDto>?> SearchGraffitiAsync(GraffitiSearchRequest request)
    {
        try
        {
            var response = await _httpClient.PostAsJsonAsync("/api/graffiti/search", request);
            response.EnsureSuccessStatusCode();
            return await response.Content.ReadFromJsonAsync<PagedResult<GraffitiDto>>();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error searching graffiti: {ex.Message}");
            return null;
        }
    }

    public async Task<GraffitiDto?> GetGraffitiByIdAsync(int id)
    {
        try
        {
            return await _httpClient.GetFromJsonAsync<GraffitiDto>($"/api/graffiti/{id}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error getting graffiti by id: {ex.Message}");
            return null;
        }
    }

    public async Task<List<GraffitiDto>?> GetGraffitiByValidatorAsync(int validatorIndex, int limit = 100)
    {
        try
        {
            return await _httpClient.GetFromJsonAsync<List<GraffitiDto>>($"/api/graffiti/validator/{validatorIndex}?limit={limit}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error getting graffiti by validator: {ex.Message}");
            return null;
        }
    }

    public async Task<Dictionary<string, int>?> GetTopGraffitiAsync(int count = 20)
    {
        try
        {
            return await _httpClient.GetFromJsonAsync<Dictionary<string, int>>($"/api/graffiti/top?count={count}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error getting top graffiti: {ex.Message}");
            return null;
        }
    }

    public async Task<ValidatorDto?> GetValidatorByIndexAsync(int validatorIndex)
    {
        try
        {
            return await _httpClient.GetFromJsonAsync<ValidatorDto>($"/api/validators/{validatorIndex}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error getting validator: {ex.Message}");
            return null;
        }
    }
}
