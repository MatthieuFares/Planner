using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PlannerAPI.Migrations
{
    /// <inheritdoc />
    public partial class AddResourceGroupToAssignments : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<int>(
                name: "ResourceId",
                table: "ResourceAssignments",
                type: "int",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "int");

            migrationBuilder.AlterColumn<int>(
                name: "AllocationPercent",
                table: "ResourceAssignments",
                type: "int",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(decimal),
                oldType: "decimal(18,2)",
                oldNullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ResourceGroupId",
                table: "ResourceAssignments",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_ResourceAssignments_ResourceGroupId",
                table: "ResourceAssignments",
                column: "ResourceGroupId");

            migrationBuilder.AddForeignKey(
                name: "FK_ResourceAssignments_ResourceGroups_ResourceGroupId",
                table: "ResourceAssignments",
                column: "ResourceGroupId",
                principalTable: "ResourceGroups",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ResourceAssignments_ResourceGroups_ResourceGroupId",
                table: "ResourceAssignments");

            migrationBuilder.DropIndex(
                name: "IX_ResourceAssignments_ResourceGroupId",
                table: "ResourceAssignments");

            migrationBuilder.DropColumn(
                name: "ResourceGroupId",
                table: "ResourceAssignments");

            migrationBuilder.AlterColumn<int>(
                name: "ResourceId",
                table: "ResourceAssignments",
                type: "int",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(int),
                oldType: "int",
                oldNullable: true);

            migrationBuilder.AlterColumn<decimal>(
                name: "AllocationPercent",
                table: "ResourceAssignments",
                type: "decimal(18,2)",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "int");
        }
    }
}
