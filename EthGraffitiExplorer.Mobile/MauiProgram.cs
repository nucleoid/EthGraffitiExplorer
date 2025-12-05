using Microsoft.Extensions.Logging;
using EthGraffitiExplorer.Mobile.Services;
using EthGraffitiExplorer.Mobile.Pages;

namespace EthGraffitiExplorer.Mobile
{
    public static class MauiProgram
    {
        public static MauiApp CreateMauiApp()
        {
            var builder = MauiApp.CreateBuilder();
            builder
                .UseMauiApp<App>()
                .ConfigureFonts(fonts =>
                {
                    fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
                    fonts.AddFont("OpenSans-Semibold.ttf", "OpenSansSemibold");
                });

            // Configure API service
            var apiBaseUrl = "https://localhost:7001"; // Update with your API URL
            builder.Services.AddHttpClient<GraffitiApiService>(client =>
            {
                client.BaseAddress = new Uri(apiBaseUrl);
            });

            // Register pages
            builder.Services.AddTransient<GraffitiListPage>();
            builder.Services.AddTransient<GraffitiDetailsPage>();
            builder.Services.AddTransient<ValidatorDetailsPage>();

#if DEBUG
    		builder.Logging.AddDebug();
#endif

            return builder.Build();
        }
    }
}
