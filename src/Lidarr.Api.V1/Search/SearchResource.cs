using Lidarr.Api.V1.Author;
using Lidarr.Api.V1.Books;
using Lidarr.Http.REST;

namespace Lidarr.Api.V1.Search
{
    public class SearchResource : RestResource
    {
        public string ForeignId { get; set; }
        public AuthorResource Author { get; set; }
        public BookResource Book { get; set; }
    }
}
