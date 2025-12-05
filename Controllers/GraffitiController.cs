using Microsoft.AspNetCore.Mvc;
using EthGraffitiExplorer.Core.Interfaces;
using EthGraffitiExplorer.Core.DTOs;

namespace EthGraffitiExplorer.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class GraffitiController : ControllerBase
{
    private readonly IGraffitiRepository _graffitiRepository;
    private readonly ILogger<GraffitiController> _logger;

    public GraffitiController(
        IGraffitiRepository graffitiRepository,
        ILogger<GraffitiController> logger)
    {
        _graffitiRepository = graffitiRepository;
        _logger = logger;
    }

    /// <summary>
    /// Get graffiti by ID
    /// </summary>
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(GraffitiDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<GraffitiDto>> GetById(int id)
    {
        var graffiti = await _graffitiRepository.GetByIdAsync(id);
        
        if (graffiti == null)
            return NotFound();

        return Ok(new GraffitiDto
        {
            Id = graffiti.Id,
            Slot = graffiti.Slot,
            Epoch = graffiti.Epoch,
            BlockNumber = graffiti.BlockNumber,
            BlockHash = graffiti.BlockHash,
            ValidatorIndex = graffiti.ValidatorIndex,
            RawGraffiti = graffiti.RawGraffiti,
            DecodedGraffiti = graffiti.DecodedGraffiti,
            Timestamp = graffiti.Timestamp,
            ProposerPubkey = graffiti.ProposerPubkey
        });
    }

    /// <summary>
    /// Search graffiti with filters and pagination
    /// </summary>
    [HttpPost("search")]
    [ProducesResponseType(typeof(PagedResult<GraffitiDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResult<GraffitiDto>>> Search([FromBody] GraffitiSearchRequest request)
    {
        var result = await _graffitiRepository.SearchAsync(request);
        
        var dtoResult = new PagedResult<GraffitiDto>
        {
            Items = result.Items.Select(g => new GraffitiDto
            {
                Id = g.Id,
                Slot = g.Slot,
                Epoch = g.Epoch,
                BlockNumber = g.BlockNumber,
                BlockHash = g.BlockHash,
                ValidatorIndex = g.ValidatorIndex,
                RawGraffiti = g.RawGraffiti,
                DecodedGraffiti = g.DecodedGraffiti,
                Timestamp = g.Timestamp,
                ProposerPubkey = g.ProposerPubkey
            }).ToList(),
            PageNumber = result.PageNumber,
            PageSize = result.PageSize,
            TotalCount = result.TotalCount,
            TotalPages = result.TotalPages
        };

        return Ok(dtoResult);
    }

    /// <summary>
    /// Get recent graffiti
    /// </summary>
    [HttpGet("recent")]
    [ProducesResponseType(typeof(List<GraffitiDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<List<GraffitiDto>>> GetRecent([FromQuery] int count = 50)
    {
        var graffitis = await _graffitiRepository.GetRecentAsync(count);
        
        var dtos = graffitis.Select(g => new GraffitiDto
        {
            Id = g.Id,
            Slot = g.Slot,
            Epoch = g.Epoch,
            BlockNumber = g.BlockNumber,
            BlockHash = g.BlockHash,
            ValidatorIndex = g.ValidatorIndex,
            RawGraffiti = g.RawGraffiti,
            DecodedGraffiti = g.DecodedGraffiti,
            Timestamp = g.Timestamp,
            ProposerPubkey = g.ProposerPubkey
        }).ToList();

        return Ok(dtos);
    }

    /// <summary>
    /// Get graffiti by validator index
    /// </summary>
    [HttpGet("validator/{validatorIndex}")]
    [ProducesResponseType(typeof(List<GraffitiDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<List<GraffitiDto>>> GetByValidator(int validatorIndex, [FromQuery] int limit = 100)
    {
        var graffitis = await _graffitiRepository.GetByValidatorIndexAsync(validatorIndex, limit);
        
        var dtos = graffitis.Select(g => new GraffitiDto
        {
            Id = g.Id,
            Slot = g.Slot,
            Epoch = g.Epoch,
            BlockNumber = g.BlockNumber,
            BlockHash = g.BlockHash,
            ValidatorIndex = g.ValidatorIndex,
            RawGraffiti = g.RawGraffiti,
            DecodedGraffiti = g.DecodedGraffiti,
            Timestamp = g.Timestamp,
            ProposerPubkey = g.ProposerPubkey
        }).ToList();

        return Ok(dtos);
    }

    /// <summary>
    /// Get top graffiti by frequency
    /// </summary>
    [HttpGet("top")]
    [ProducesResponseType(typeof(Dictionary<string, int>), StatusCodes.Status200OK)]
    public async Task<ActionResult<Dictionary<string, int>>> GetTopGraffiti([FromQuery] int count = 20)
    {
        var topGraffiti = await _graffitiRepository.GetTopGraffitiAsync(count);
        return Ok(topGraffiti);
    }

    /// <summary>
    /// Get total graffiti count
    /// </summary>
    [HttpGet("count")]
    [ProducesResponseType(typeof(int), StatusCodes.Status200OK)]
    public async Task<ActionResult<int>> GetCount()
    {
        var count = await _graffitiRepository.GetCountAsync();
        return Ok(count);
    }
}
