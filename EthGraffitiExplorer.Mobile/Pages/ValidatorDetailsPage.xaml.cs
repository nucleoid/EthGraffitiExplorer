using System.ComponentModel;
using System.Runtime.CompilerServices;
using EthGraffitiExplorer.Core.DTOs;
using EthGraffitiExplorer.Mobile.Services;

namespace EthGraffitiExplorer.Mobile.Pages;

[QueryProperty(nameof(ValidatorIndex), "validatorIndex")]
public partial class ValidatorDetailsPage : INotifyPropertyChanged
{
    private readonly GraffitiApiService _apiService;
    private bool _isLoading;
    private ValidatorDto? _validator;
    private int _validatorIndex;

    public ValidatorDetailsPage(GraffitiApiService apiService)
    {
        InitializeComponent();
        _apiService = apiService;
        BindingContext = this;
    }

    public int ValidatorIndex
    {
        get => _validatorIndex;
        set
        {
            _validatorIndex = value;
            OnPropertyChanged();
            LoadValidator();
        }
    }

    public ValidatorDto? Validator
    {
        get => _validator;
        set
        {
            _validator = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(IsDataLoaded));
            OnPropertyChanged(nameof(StatusText));
            OnPropertyChanged(nameof(StatusColor));
            OnPropertyChanged(nameof(BalanceText));
        }
    }

    public bool IsLoading
    {
        get => _isLoading;
        set
        {
            _isLoading = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(IsDataLoaded));
        }
    }

    public bool IsDataLoaded => !IsLoading && Validator != null;

    public string StatusText => Validator?.IsActive == true ? "Active" : "Inactive";

    public Color StatusColor => Validator?.IsActive == true ? Colors.Green : Colors.Gray;

    public string BalanceText => Validator != null 
        ? $"{(Validator.EffectiveBalance / 1_000_000_000.0):N2} ETH" 
        : "";

    private async void LoadValidator()
    {
        IsLoading = true;
        try
        {
            Validator = await _apiService.GetValidatorByIndexAsync(ValidatorIndex);
            if (Validator == null)
            {
                await DisplayAlert("Error", "Validator not found", "OK");
                await Shell.Current.GoToAsync("..");
            }
        }
        catch (Exception ex)
        {
            await DisplayAlert("Error", $"Failed to load validator: {ex.Message}", "OK");
        }
        finally
        {
            IsLoading = false;
        }
    }

    private async void OnBackClicked(object sender, EventArgs e)
    {
        await Shell.Current.GoToAsync("..");
    }

    public new event PropertyChangedEventHandler? PropertyChanged;

    protected new void OnPropertyChanged([CallerMemberName] string? propertyName = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
