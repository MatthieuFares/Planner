using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PlannerAPI.Migrations
{
    /// <inheritdoc />
    public partial class AddCpmFieldsToTasks : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "EarlyFinish",
                table: "PlannerTasks",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "EarlyStart",
                table: "PlannerTasks",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LateFinish",
                table: "PlannerTasks",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LateStart",
                table: "PlannerTasks",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "TotalFloat",
                table: "PlannerTasks",
                type: "int",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "EarlyFinish",
                table: "PlannerTasks");

            migrationBuilder.DropColumn(
                name: "EarlyStart",
                table: "PlannerTasks");

            migrationBuilder.DropColumn(
                name: "LateFinish",
                table: "PlannerTasks");

            migrationBuilder.DropColumn(
                name: "LateStart",
                table: "PlannerTasks");

            migrationBuilder.DropColumn(
                name: "TotalFloat",
                table: "PlannerTasks");
        }
    }
}
