using EthGraffitiExplorer.Mobile.Pages;

namespace EthGraffitiExplorer.Mobile
{
    public partial class AppShell : Shell
    {
        public AppShell()
        {
            InitializeComponent();

            // Register routes for navigation
            Routing.RegisterRoute("graffitidetails", typeof(GraffitiDetailsPage));
            Routing.RegisterRoute("validatordetails", typeof(ValidatorDetailsPage));
        }
    }
}
