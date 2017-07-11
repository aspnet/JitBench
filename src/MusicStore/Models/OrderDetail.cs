using System.ComponentModel.DataAnnotations.Schema;

namespace MusicStore.Models
{
    public class OrderDetail
    {
        public int OrderDetailId { get; set; }

        public int OrderId { get; set; }

        public int AlbumId { get; set; }

        public int Quantity { get; set; }

        public decimal UnitPrice { get; set; }

        public virtual Album Album { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public virtual Order Order { get; set; }
    }
}