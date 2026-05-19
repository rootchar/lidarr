using System.Collections.Generic;

namespace NzbDrone.Core.ImportLists.Lidarr
{
    public class LidarrAuthor
    {
        public string AuthorName { get; set; }
        public int Id { get; set; }
        public string ForeignAuthorId { get; set; }
        public string Overview { get; set; }
        public List<MediaCover.MediaCover> Images { get; set; }
        public bool Monitored { get; set; }
        public int QualityProfileId { get; set; }
        public string RootFolderPath { get; set; }
        public HashSet<int> Tags { get; set; }
    }

    public class LidarrEdition
    {
        public string Title { get; set; }
        public string ForeignEditionId { get; set; }
        public string Overview { get; set; }
        public List<MediaCover.MediaCover> Images { get; set; }
        public bool Monitored { get; set; }
    }

    public class LidarrBook
    {
        public string Title { get; set; }
        public string ForeignBookId { get; set; }
        public string ForeignEditionId { get; set; }
        public string Overview { get; set; }
        public List<MediaCover.MediaCover> Images { get; set; }
        public bool Monitored { get; set; }
        public LidarrAuthor Author { get; set; }
        public int AuthorId { get; set; }
        public List<LidarrEdition> Editions { get; set; }
    }

    public class LidarrProfile
    {
        public string Name { get; set; }
        public int Id { get; set; }
    }

    public class LidarrTag
    {
        public string Label { get; set; }
        public int Id { get; set; }
    }

    public class LidarrRootFolder
    {
        public string Path { get; set; }
        public int Id { get; set; }
    }
}
