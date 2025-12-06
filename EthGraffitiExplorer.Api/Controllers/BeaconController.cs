using Microsoft.AspNetCore.Mvc;
using EthGraffitiExplorer.Core.Interfaces;
using EthGraffitiExplorer.Core.Services;

namespace EthGraffitiExplorer.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BeaconController : ControllerBase
{
    private readonly IBeaconChainService _beaconService;
    private readonly IGraffitiRepository _graffitiRepository;
    private readonly IBeaconBlockRepository _blockRepository;
    private readonly ILogger<BeaconController> _logger;

    public BeaconController(
        IBeaconChainService beaconService,
        IGraffitiRepository graffitiRepository,
        IBeaconBlockRepository blockRepository,
        ILogger<BeaconController> logger)
    {
        _beaconService = beaconService;
        _graffitiRepository = graffitiRepository;
        _blockRepository = blockRepository;
        _logger = logger;
    }

    /// <summary>
    /// Get current slot from beacon node
    /// </summary>
    [HttpGet("current-slot")]
    [ProducesResponseType(typeof(long), StatusCodes.Status200OK)]
    public async Task<ActionResult<long>> GetCurrentSlot()
    {
        var slot = await _beaconService.GetCurrentSlotAsync();
        return Ok(slot);
    }

    /// <summary>
    /// Get finalized slot from beacon node
    /// </summary>
    [HttpGet("finalized-slot")]
    [ProducesResponseType(typeof(long), StatusCodes.Status200OK)]
    public async Task<ActionResult<long>> GetFinalizedSlot()
    {
        var slot = await _beaconService.GetFinalizedSlotAsync();
        return Ok(slot);
    }

    /// <summary>
    /// Check beacon node health
    /// </summary>
    [HttpGet("health")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status503ServiceUnavailable)]
    public async Task<ActionResult> CheckHealth()
    {
        var isHealthy = await _beaconService.IsNodeHealthyAsync();
        
        if (isHealthy)
            return Ok(new { status = "healthy" });
        
        return StatusCode(StatusCodes.Status503ServiceUnavailable, new { status = "unhealthy" });
    }

    /// <summary>
    /// Sync blocks from beacon node (admin endpoint)
    /// </summary>
    [HttpPost("sync")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<ActionResult> SyncBlocks([FromQuery] long? fromSlot = null, [FromQuery] long? toSlot = null)
    {
        try
        {
            var startSlot = fromSlot ?? await _blockRepository.GetLatestProcessedSlotAsync() ?? 0;
            var endSlot = toSlot ?? await _beaconService.GetFinalizedSlotAsync();

            var processedCount = 0;
            
            for (long slot = startSlot; slot <= endSlot && processedCount < 100; slot++)
            {
                if (await _blockRepository.ExistsAsync(slot))
                    continue;

                var block = await _beaconService.GetBlockBySlotAsync(slot);
                if (block == null)
                    continue;

                await _blockRepository.AddAsync(block);

                // Process graffiti
                if (!string.IsNullOrEmpty(block.Graffiti))
                {
                    var decodedGraffiti = GraffitiDecoder.DecodeGraffiti(block.Graffiti);
                    
                    var graffiti = new Core.Models.ValidatorGraffiti
                    {
                        Slot = block.Slot,
                        Epoch = block.Epoch,
                        BlockNumber = block.Slot, // Simplified for beacon chain
                        BlockHash = block.BlockHash,
                        ValidatorIndex = block.ProposerIndex,
                        RawGraffiti = block.Graffiti,
                        DecodedGraffiti = decodedGraffiti,
                        Timestamp = block.Timestamp
                    };

                    await _graffitiRepository.AddAsync(graffiti);
                }

                block.IsProcessed = true;
                await _blockRepository.UpdateAsync(block);
                
                processedCount++;
            }

            return Ok(new { processedCount, startSlot, endSlot });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error syncing blocks");
            return StatusCode(500, new { error = ex.Message });
        }
    }
}
