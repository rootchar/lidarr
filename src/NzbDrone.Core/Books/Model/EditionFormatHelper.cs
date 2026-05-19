using System.Collections.Generic;

namespace NzbDrone.Core.Books
{
    public static class EditionFormatHelper
    {
        public static readonly HashSet<string> AudiobookFormats = new HashSet<string>(System.StringComparer.OrdinalIgnoreCase)
        {
            "Audiobook",
            "Audio CD",
            "Audio Cassette",
            "Audible Audio",
            "CD-ROM",
            "MP3 CD"
        };

        public static bool IsAudiobook(string format) =>
            !string.IsNullOrWhiteSpace(format) && AudiobookFormats.Contains(format);
    }
}
