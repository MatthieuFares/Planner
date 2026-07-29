using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PlannerAPI.Migrations
{
    /// <inheritdoc />
    public partial class AddCanManageResources : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "CanManageResources",
                table: "AspNetUsers",
                type: "bit",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CanManageResources",
                table: "AspNetUsers");
        }
    }
}
