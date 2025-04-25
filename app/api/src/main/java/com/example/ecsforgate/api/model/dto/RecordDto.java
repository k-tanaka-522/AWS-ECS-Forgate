package com.example.ecsforgate.api.model.dto;

import com.example.ecsforgate.api.model.Record;
import com.example.ecsforgate.api.model.RecordStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.OffsetDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RecordDto {
    private UUID id;
    private String title;
    private String content;
    private RecordStatus status;
    private String createdBy;
    private OffsetDateTime createdAt;
    private String updatedBy;
    private OffsetDateTime updatedAt;

    public static RecordDto fromEntity(Record record) {
        return RecordDto.builder()
                .id(record.getId())
                .title(record.getTitle())
                .content(record.getContent())
                .status(record.getStatus())
                .createdBy(record.getCreatedBy())
                .createdAt(record.getCreatedAt())
                .updatedBy(record.getUpdatedBy())
                .updatedAt(record.getUpdatedAt())
                .build();
    }
}
