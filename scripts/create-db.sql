CREATE DATABASE [TasteWhisky]
GO
USE [TasteWhisky]
GO

CREATE TABLE [dbo].[Bottles]
(
	[Id] [int] IDENTITY (1,1) NOT NULL,
	[Name] [nvarchar] (100) NOT NULL,
	[DistilleryId] [int] NOT NULL,
	[Age] [int] NOT NULL,
	[AlcoholByVolume] [real] NOT NULL,
	[WhiskyBaseId] [int] NULL,
	CONSTRAINT [PK_Bottles] PRIMARY KEY CLUSTERED
	(
		[Id] ASC
	) WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY  = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Bottles_DistilleryId] ON [dbo].[Bottles]
(
	[DistilleryId] ASC
) WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY  = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
CREATE TABLE [dbo].[Customers]
(
	[Id] [int] IDENTITY (1,1) NOT NULL,
	[FirstName] [nvarchar] (100) NOT NULL,
	[LastName] [nvarchar] (100) NOT NULL,
	[DateOfBirth] [datetime] NOT NULL,
	[Address] [nvarchar] (100) NULL,
	CONSTRAINT [PK_Customers] PRIMARY KEY CLUSTERED
	(
		[Id] ASC
	) WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY  = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
CREATE TABLE [dbo].[Distilleries]
(
	[Id] [int] IDENTITY (1,1) NOT NULL,
	[Name] [nvarchar] (100) NOT NULL,
	CONSTRAINT [PK_Distilleries] PRIMARY KEY CLUSTERED
	(
		[Id] ASC
	) WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY  = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
CREATE TABLE [dbo].[Orders]
(
	[Id] [int] IDENTITY (1,1) NOT NULL,
	[CustomerId] [int] NOT NULL,
	[Date] [datetime] NOT NULL,
	[Total] [decimal] (18,2) NOT NULL,
	[BottleId] [int] NOT NULL,
	CONSTRAINT [PK_Orders] PRIMARY KEY CLUSTERED
	(
		[Id] ASC
	) WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY  = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Orders_BottleId] ON [dbo].[Orders]
(
	[BottleId] ASC
) WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY  = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Orders_CustomerId] ON [dbo].[Orders]
(
	[CustomerId] ASC
) WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY  = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
CREATE TABLE [dbo].[Tastings]
(
	[Id] [int] IDENTITY (1,1) NOT NULL,
	[BottleId] [int] NOT NULL,
	[CustomerId] [int] NOT NULL,
	[Date] [datetime] NOT NULL,
	[Rating] [int] NOT NULL,
	[Notes] [nvarchar] (100) NOT NULL,
	CONSTRAINT [PK_Tastings] PRIMARY KEY CLUSTERED
	(
		[Id] ASC
	) WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY  = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Tastings_BottleId] ON [dbo].[Tastings]
(
	[BottleId] ASC
) WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY  = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Tastings_CustomerId] ON [dbo].[Tastings]
(
	[CustomerId] ASC
) WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY  = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
CREATE VIEW [dbo].[vw_TastingDetails]
AS (
   SELECT
        t.Id AS TastingId,
        CONCAT(c.FirstName, ' ', c.LastName) AS CustomerName,
        t.Date AS DateTasted,
        d.Name AS DistilleryName,
        b.Name AS BottleName,
        b.Age AS BottleAge,
        t.Notes AS TastingNotes,
        t.Rating AS BottleRating
   FROM dbo.Tastings t
        JOIN dbo.Customers c ON c.Id = t.CustomerId
        JOIN dbo.Bottles b ON b.Id = t.BottleId
        JOIN dbo.Distilleries d ON d.Id = b.DistilleryId);
GO
ALTER TABLE [dbo].[Bottles] ADD CONSTRAINT [FK_Bottles_Distilleries_DistilleryId] FOREIGN KEY
	(
		[DistilleryId]
	)
	REFERENCES [dbo].[Distilleries]
	(
		[Id]
	) ON DELETE CASCADE
GO

ALTER TABLE [dbo].[Orders] ADD CONSTRAINT [FK_Orders_Bottles_BottleId] FOREIGN KEY
	(
		[BottleId]
	)
	REFERENCES [dbo].[Bottles]
	(
		[Id]
	) ON DELETE CASCADE
GO

ALTER TABLE [dbo].[Orders] ADD CONSTRAINT [FK_Orders_Customers_CustomerId] FOREIGN KEY
	(
		[CustomerId]
	)
	REFERENCES [dbo].[Customers]
	(
		[Id]
	) ON DELETE CASCADE
GO

ALTER TABLE [dbo].[Tastings] ADD CONSTRAINT [FK_Tastings_Bottles_BottleId] FOREIGN KEY
	(
		[BottleId]
	)
	REFERENCES [dbo].[Bottles]
	(
		[Id]
	) ON DELETE CASCADE
GO

ALTER TABLE [dbo].[Tastings] ADD CONSTRAINT [FK_Tastings_Customers_CustomerId] FOREIGN KEY
	(
		[CustomerId]
	)
	REFERENCES [dbo].[Customers]
	(
		[Id]
	) ON DELETE CASCADE
GO

CREATE PROCEDURE [dbo].[InsertNewBottle]
   @BottleName NVARCHAR(100),
   @Age INT,
   @AlcoholByVolume REAL,
   @DistilleryName NVARCHAR(100)
AS
BEGIN
   DECLARE @DistilleryId INT;

   /* Determine DistilleryId by it's name*/
   SELECT @DistilleryId = d.Id
   FROM   dbo.Distilleries AS d
   WHERE  LOWER(d.Name) = LOWER(@DistilleryName);

   IF @DistilleryId IS NULL
   BEGIN
      INSERT dbo.Distilleries
      (
         Name
      )
      VALUES
      (
         @DistilleryName
      );

      SET @DistilleryId = SCOPE_IDENTITY();
   END;

   /* Insert the new bottle */
   INSERT dbo.Bottles
   (
      Name,
      DistilleryId,
      Age,
      AlcoholByVolume
   )
   VALUES
   (
      @BottleName,
      @DistilleryId,
      @Age,
      @AlcoholByVolume
   );

END;
GO
