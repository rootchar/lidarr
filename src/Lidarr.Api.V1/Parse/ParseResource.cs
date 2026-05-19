using System.Collections.Generic;
using Lidarr.Api.V1.Author;
using Lidarr.Api.V1.Books;
using Lidarr.Http.REST;
using NzbDrone.Core.Parser.Model;

namespace Lidarr.Api.V1.Parse
{
    public class ParseResource : RestResource
    {
        public string Title { get; set; }
        public ParsedBookInfo ParsedBookInfo { get; set; }
        public AuthorResource Author { get; set; }
        public List<BookResource> Books { get; set; }
    }
}
