using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using EthGraffitiExplorer.Core.DTOs;
using EthGraffitiExplorer.Mobile.Services;

namespace EthGraffitiExplorer.Mobile.Pages;

public partial class GraffitiListPage : ContentPage, INotifyPropertyChanged
{
    private readonly GraffitiApiService _apiService;
    private bool _isLoading;
    private string? _searchTerm;
    private string? _validatorIndexText;

    public GraffitiListPage(GraffitiApiService apiService)
    {
        InitializeComponent();
        _apiService = apiService;
        BindingContext = this;
        LoadRecentGraffiti();
    }

    public ObservableCollection<GraffitiDto> Graffitis { get; } = new();

    public bool IsLoading
    {
        get => _isLoading;
        set
        {
            _isLoading = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(IsEmpty));
        }
    }

    public bool IsEmpty => !IsLoading && Graffitis.Count == 0;

    public string? SearchTerm
    {
        get => _searchTerm;
        set
        {
            _searchTerm = value;
            OnPropertyChanged();
        }
    }

    public string? ValidatorIndexText
    {
        get => _validatorIndexText;
        set
        {
            _validatorIndexText = value;
            OnPropertyChanged();
        }
    }

    private async void LoadRecentGraffiti()
    {
        IsLoading = true;
        try
        {
            var graffitis = await _apiService.GetRecentGraffitiAsync(50);
            if (graffitis != null)
            {
                Graffitis.Clear();
                foreach (var graffiti in graffitis)
                {
                    Graffitis.Add(graffiti);
                }
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

    private async void OnSearchClicked(object sender, EventArgs e)
    {
        IsLoading = true;
        try
        {
            int? validatorIndex = null;
            if (!string.IsNullOrWhiteSpace(ValidatorIndexText) && int.TryParse(ValidatorIndexText, out var index))
            {
                validatorIndex = index;
            }

            var request = new GraffitiSearchRequest
            {
                SearchTerm = SearchTerm,
                ValidatorIndex = validatorIndex,
                PageSize = 50
            };

            var result = await _apiService.SearchGraffitiAsync(request);
            if (result != null)
            {
                Graffitis.Clear();
                foreach (var graffiti in result.Items)
                {
                    Graffitis.Add(graffiti);
                }
            }
        }
        catch (Exception ex)
        {
            await DisplayAlert("Error", $"Search failed: {ex.Message}", "OK");
        }
        finally
        {
            IsLoading = false;
        }
    }

    private async void OnGraffitiSelected(object sender, SelectionChangedEventArgs e)
    {
        if (e.CurrentSelection.FirstOrDefault() is GraffitiDto graffiti)
        {
            await Shell.Current.GoToAsync($"graffitidetails?id={graffiti.Id}");
            ((CollectionView)sender).SelectedItem = null;
        }
    }

    public new event PropertyChangedEventHandler? PropertyChanged;

    protected new void OnPropertyChanged([CallerMemberName] string? propertyName = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
