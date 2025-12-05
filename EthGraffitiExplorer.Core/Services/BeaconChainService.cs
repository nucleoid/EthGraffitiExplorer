using System.Text.Json;
using System.Text.Json.Serialization;
using EthGraffitiExplorer.Core.Models;
using EthGraffitiExplorer.Core.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace EthGraffitiExplorer.Core.Services;

public class BeaconChainService : IBeaconChainService
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<BeaconChainService> _logger;
    private readonly string _beaconNodeUrl;
    private readonly JsonSerializerOptions _jsonOptions;

    public BeaconChainService(
        HttpClient httpClient,
        IConfiguration configuration,
        ILogger<BeaconChainService> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        _beaconNodeUrl = configuration["BeaconNode:Url"] ?? "http://localhost:5052";
        
        _jsonOptions = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
            NumberHandling = JsonNumberHandling.AllowReadingFromString
        };
    }

    public async Task<BeaconBlock?> GetBlockBySlotAsync(long slot)
    {
        try
        {
            var url = $"{_beaconNodeUrl}/eth/v2/beacon/blocks/{slot}";
            var response = await _httpClient.GetAsync(url);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("Failed to get block for slot {Slot}: {StatusCode}", slot, response.StatusCode);
                return null;
            }

            var content = await response.Content.ReadAsStringAsync();
            var beaconResponse = JsonSerializer.Deserialize<BeaconApiResponse>(content, _jsonOptions);

            if (beaconResponse?.Data?.Message == null)
                return null;

            var blockData = beaconResponse.Data.Message;
            var blockRoot = beaconResponse.Data.Root ?? string.Empty;

            return new BeaconBlock
            {
                Slot = blockData.Slot,
                Epoch = blockData.Slot / 32, // 32 slots per epoch
                BlockHash = blockRoot,
                ParentHash = blockData.ParentRoot,
                StateRoot = blockData.StateRoot ?? string.Empty,
                ProposerIndex = blockData.ProposerIndex,
                Graffiti = blockData.Body?.Graffiti ?? string.Empty,
                Timestamp = DateTimeOffset.FromUnixTimeSeconds(
                    1606824023 + (blockData.Slot * 12)).UtcDateTime, // Genesis + slot duration
                IsProcessed = false
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching block for slot {Slot}", slot);
            return null;
        }
    }

    public async Task<List<BeaconBlock>> GetBlocksInRangeAsync(long fromSlot, long toSlot)
    {
        var blocks = new List<BeaconBlock>();
        
        for (long slot = fromSlot; slot <= toSlot; slot++)
        {
            var block = await GetBlockBySlotAsync(slot);
            if (block != null)
            {
                blocks.Add(block);
            }
            
            // Add small delay to avoid overwhelming the node
            await Task.Delay(100);
        }

        return blocks;
    }

    public async Task<long> GetCurrentSlotAsync()
    {
        try
        {
            var url = $"{_beaconNodeUrl}/eth/v1/beacon/headers/head";
            var response = await _httpClient.GetAsync(url);

            if (!response.IsSuccessStatusCode)
                return 0;

            var content = await response.Content.ReadAsStringAsync();
            var headerResponse = JsonSerializer.Deserialize<BeaconHeaderResponse>(content, _jsonOptions);

            return headerResponse?.Data?.Header?.Message?.Slot ?? 0;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching current slot");
            return 0;
        }
    }

    public async Task<long> GetFinalizedSlotAsync()
    {
        try
        {
            var url = $"{_beaconNodeUrl}/eth/v1/beacon/states/finalized/finality_checkpoints";
            var response = await _httpClient.GetAsync(url);

            if (!response.IsSuccessStatusCode)
                return 0;

            var content = await response.Content.ReadAsStringAsync();
            var checkpointResponse = JsonSerializer.Deserialize<FinalityCheckpointResponse>(content, _jsonOptions);

            var finalizedEpoch = checkpointResponse?.Data?.Finalized?.Epoch ?? 0;
            return finalizedEpoch * 32; // Convert epoch to slot
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching finalized slot");
            return 0;
        }
    }

    public async Task<Validator?> GetValidatorByIndexAsync(int validatorIndex)
    {
        try
        {
            var url = $"{_beaconNodeUrl}/eth/v1/beacon/states/head/validators/{validatorIndex}";
            var response = await _httpClient.GetAsync(url);

            if (!response.IsSuccessStatusCode)
                return null;

            var content = await response.Content.ReadAsStringAsync();
            var validatorResponse = JsonSerializer.Deserialize<ValidatorResponse>(content, _jsonOptions);

            if (validatorResponse?.Data?.Validator == null)
                return null;

            var validator = validatorResponse.Data.Validator;
            var status = validatorResponse.Data.Status ?? string.Empty;

            return new Validator
            {
                ValidatorIndex = validatorIndex,
                Pubkey = validator.Pubkey ?? string.Empty,
                WithdrawalAddress = validator.WithdrawalCredentials,
                EffectiveBalance = validator.EffectiveBalance,
                IsActive = status.Contains("active", StringComparison.OrdinalIgnoreCase),
                ActivationEpoch = validator.ActivationEpoch,
                ExitEpoch = validator.ExitEpoch
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching validator {ValidatorIndex}", validatorIndex);
            return null;
        }
    }

    public async Task<bool> IsNodeHealthyAsync()
    {
        try
        {
            var url = $"{_beaconNodeUrl}/eth/v1/node/health";
            var response = await _httpClient.GetAsync(url);
            return response.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }

    // Internal API response models
    private class BeaconApiResponse
    {
        public BeaconBlockData? Data { get; set; }
    }

    private class BeaconBlockData
    {
        public BeaconBlockMessage? Message { get; set; }
        public string? Root { get; set; }
    }

    private class BeaconBlockMessage
    {
        public long Slot { get; set; }
        
        [JsonPropertyName("proposer_index")]
        public int ProposerIndex { get; set; }
        
        [JsonPropertyName("parent_root")]
        public string? ParentRoot { get; set; }
        
        [JsonPropertyName("state_root")]
        public string? StateRoot { get; set; }
        
        public BeaconBlockBody? Body { get; set; }
    }

    private class BeaconBlockBody
    {
        public string? Graffiti { get; set; }
    }

    private class BeaconHeaderResponse
    {
        public HeaderData? Data { get; set; }
    }

    private class HeaderData
    {
        public HeaderWrapper? Header { get; set; }
    }

    private class HeaderWrapper
    {
        public BeaconBlockMessage? Message { get; set; }
    }

    private class FinalityCheckpointResponse
    {
        public FinalityData? Data { get; set; }
    }

    private class FinalityData
    {
        public Checkpoint? Finalized { get; set; }
    }

    private class Checkpoint
    {
        public long Epoch { get; set; }
    }

    private class ValidatorResponse
    {
        public ValidatorData? Data { get; set; }
    }

    private class ValidatorData
    {
        public ValidatorInfo? Validator { get; set; }
        public string? Status { get; set; }
    }

    private class ValidatorInfo
    {
        public string? Pubkey { get; set; }
        
        [JsonPropertyName("withdrawal_credentials")]
        public string? WithdrawalCredentials { get; set; }
        
        [JsonPropertyName("effective_balance")]
        public long EffectiveBalance { get; set; }
        
        [JsonPropertyName("activation_epoch")]
        public long? ActivationEpoch { get; set; }
        
        [JsonPropertyName("exit_epoch")]
        public long? ExitEpoch { get; set; }
    }
}
