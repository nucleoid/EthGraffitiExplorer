namespace EthGraffitiExplorer.Core.Services;

public class GraffitiDecoder
{
    /// <summary>
    /// Decodes graffiti bytes to readable string, handling non-printable characters
    /// </summary>
    public static string DecodeGraffiti(string hexGraffiti)
    {
        if (string.IsNullOrWhiteSpace(hexGraffiti))
            return string.Empty;

        // Remove 0x prefix if present
        hexGraffiti = hexGraffiti.StartsWith("0x", StringComparison.OrdinalIgnoreCase)
            ? hexGraffiti[2..]
            : hexGraffiti;

        try
        {
            // Convert hex to bytes
            var bytes = Convert.FromHexString(hexGraffiti);
            
            // Find the last non-zero byte (graffiti is right-padded with zeros)
            int lastNonZero = bytes.Length - 1;
            while (lastNonZero >= 0 && bytes[lastNonZero] == 0)
                lastNonZero--;

            if (lastNonZero < 0)
                return string.Empty;

            // Extract only the meaningful bytes
            var meaningfulBytes = bytes[..(lastNonZero + 1)];
            
            // Try UTF-8 decoding first
            var decoded = System.Text.Encoding.UTF8.GetString(meaningfulBytes);
            
            // Replace non-printable characters with their hex representation
            var result = new System.Text.StringBuilder();
            foreach (var c in decoded)
            {
                if (char.IsControl(c) && c != '\n' && c != '\r' && c != '\t')
                {
                    result.Append($"\\x{((int)c):X2}");
                }
                else
                {
                    result.Append(c);
                }
            }

            return result.ToString().Trim();
        }
        catch
        {
            // If decoding fails, return hex representation
            return $"0x{hexGraffiti}";
        }
    }

    /// <summary>
    /// Checks if graffiti appears to be valid text
    /// </summary>
    public static bool IsValidText(string graffiti)
    {
        if (string.IsNullOrWhiteSpace(graffiti))
            return false;

        // Count printable characters
        int printableCount = graffiti.Count(c => !char.IsControl(c) || c == '\n' || c == '\r' || c == '\t');
        
        // Consider it valid text if more than 70% of characters are printable
        return (double)printableCount / graffiti.Length > 0.7;
    }
}
