using Microsoft.AspNetCore.Mvc;
using EthGraffitiExplorer.Core.Interfaces;
using EthGraffitiExplorer.Core.DTOs;

namespace EthGraffitiExplorer.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ValidatorsController : ControllerBase
{
    private readonly IValidatorRepository _validatorRepository;
    private readonly ILogger<ValidatorsController> _logger;

    public ValidatorsController(
        IValidatorRepository validatorRepository,
        ILogger<ValidatorsController> logger)
    {
        _validatorRepository = validatorRepository;
        _logger = logger;
    }

    /// <summary>
    /// Get validator by index
    /// </summary>
    [HttpGet("{validatorIndex}")]
    [ProducesResponseType(typeof(ValidatorDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ValidatorDto>> GetByIndex(int validatorIndex)
    {
        var validator = await _validatorRepository.GetByIndexAsync(validatorIndex);
        
        if (validator == null)
            return NotFound();

        return Ok(new ValidatorDto
        {
            ValidatorIndex = validator.ValidatorIndex,
            Pubkey = validator.Pubkey,
            WithdrawalAddress = validator.WithdrawalAddress,
            EffectiveBalance = validator.EffectiveBalance,
            IsActive = validator.IsActive,
            ActivationEpoch = validator.ActivationEpoch,
            ExitEpoch = validator.ExitEpoch,
            GraffitiCount = validator.Graffitis.Count
        });
    }

    /// <summary>
    /// Get validator by public key
    /// </summary>
    [HttpGet("pubkey/{pubkey}")]
    [ProducesResponseType(typeof(ValidatorDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ValidatorDto>> GetByPubkey(string pubkey)
    {
        var validator = await _validatorRepository.GetByPubkeyAsync(pubkey);
        
        if (validator == null)
            return NotFound();

        return Ok(new ValidatorDto
        {
            ValidatorIndex = validator.ValidatorIndex,
            Pubkey = validator.Pubkey,
            WithdrawalAddress = validator.WithdrawalAddress,
            EffectiveBalance = validator.EffectiveBalance,
            IsActive = validator.IsActive,
            ActivationEpoch = validator.ActivationEpoch,
            ExitEpoch = validator.ExitEpoch,
            GraffitiCount = validator.Graffitis.Count
        });
    }

    /// <summary>
    /// Get active validators
    /// </summary>
    [HttpGet("active")]
    [ProducesResponseType(typeof(List<ValidatorDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<List<ValidatorDto>>> GetActiveValidators([FromQuery] int limit = 100)
    {
        var validators = await _validatorRepository.GetActiveValidatorsAsync(limit);
        
        var dtos = validators.Select(v => new ValidatorDto
        {
            ValidatorIndex = v.ValidatorIndex,
            Pubkey = v.Pubkey,
            WithdrawalAddress = v.WithdrawalAddress,
            EffectiveBalance = v.EffectiveBalance,
            IsActive = v.IsActive,
            ActivationEpoch = v.ActivationEpoch,
            ExitEpoch = v.ExitEpoch,
            GraffitiCount = v.Graffitis.Count
        }).ToList();

        return Ok(dtos);
    }
}
