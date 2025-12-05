using System.ComponentModel;
using System.Runtime.CompilerServices;
using EthGraffitiExplorer.Core.DTOs;
using EthGraffitiExplorer.Mobile.Services;

namespace EthGraffitiExplorer.Mobile.Pages;

[QueryProperty(nameof(GraffitiId), "id")]
public partial class GraffitiDetailsPage : ContentPage, INotifyPropertyChanged
{
    private readonly GraffitiApiService _apiService;
    private bool _isLoading;
    private GraffitiDto? _graffiti;
    private int _graffitiId;

    public GraffitiDetailsPage(GraffitiApiService apiService)
    {
        InitializeComponent();
        _apiService = apiService;
        BindingContext = this;
    }

    public int GraffitiId
    {
        get => _graffitiId;
        set
        {
            _graffitiId = value;
            OnPropertyChanged();
            LoadGraffiti();
        }
    }

    public GraffitiDto? Graffiti
    {
        get => _graffiti;
        set
        {
            _graffiti = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(IsLoaded));
        }
    }

    public bool IsLoading
    {
        get => _isLoading;
        set
        {
            _isLoading = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(IsLoaded));
        }
    }

    public bool IsLoaded => !IsLoading && Graffiti != null;

    private async void LoadGraffiti()
    {
        IsLoading = true;
        try
        {
            Graffiti = await _apiService.GetGraffitiByIdAsync(GraffitiId);
            if (Graffiti == null)
            {
                await DisplayAlert("Error", "Graffiti not found", "OK");
                await Shell.Current.GoToAsync("..");
            }
        }
        catch (Exception ex)
        {
            await DisplayAlert("Error", $"Failed to load graffiti: {ex.Message}", "OK");
        }
        finally
        {
            IsLoading = false;
        }
    }

    private async void OnViewValidatorClicked(object sender, EventArgs e)
    {
        if (Graffiti != null)
        {
            await Shell.Current.GoToAsync($"validatordetails?validatorIndex={Graffiti.ValidatorIndex}");
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
